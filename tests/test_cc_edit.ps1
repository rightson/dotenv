# Tests for bin/cc-edit.ps1 and inc/claude.ps1. Runs on Windows PowerShell 5.1
# and on PowerShell 7 (Windows, macOS, Linux). Editors are replaced by stubs
# that log their arguments and append a line to the file, so no GUI is needed.
#
#   powershell -NoProfile -File tests\test_cc_edit.ps1
#   pwsh -NoProfile -File tests/test_cc_edit.ps1

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
$ccEdit = Join-Path $repoRoot 'bin/cc-edit.ps1'
$psExe = (Get-Process -Id $PID).Path
$onWindows = $env:OS -eq 'Windows_NT'

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("cc-edit-test-" + [guid]::NewGuid())
$stubs = Join-Path $testRoot 'stubs'
$homeDir = Join-Path $testRoot 'home'
$log = Join-Path $testRoot 'editor.log'
$prompt = Join-Path $testRoot 'prompt.md'
$conf = Join-Path $homeDir '.config/cc-edit/config'
$drafts = Join-Path $homeDir '.claude-prompts'
New-Item -ItemType Directory -Force -Path $stubs, $homeDir | Out-Null

$sep = [IO.Path]::PathSeparator
# The child PATH holds the stubs plus only what they need, so a real editor in
# a system directory (e.g. /usr/bin/code from the VS Code .deb) is never found.
if ($onWindows) {
    $systemPath = "$env:SystemRoot\System32;$env:SystemRoot"
}
else {
    $systemPath = Join-Path $testRoot 'sysbin'
    New-Item -ItemType Directory -Force -Path $systemPath | Out-Null
    $sleep = (Get-Command sleep -CommandType Application | Select-Object -First 1).Source
    $null = New-Item -ItemType SymbolicLink -Path (Join-Path $systemPath 'sleep') -Target $sleep
}

# New-Stub NAME ARGINDEX [DELAY]: an editor that logs "NAME args", waits DELAY
# seconds, then appends "edited by NAME" to its argument number ARGINDEX.
function New-Stub([string]$Name, [int]$ArgIndex, [int]$Delay = 0, [int]$ExitCode = 0) {
    if ($onWindows) {
        $wait = if ($Delay) { "ping -n $($Delay + 1) 127.0.0.1 >nul" } else { '' }
        Set-Content -LiteralPath (Join-Path $stubs "$Name.cmd") -Encoding ASCII -Value @(
            '@echo off', "echo $Name %*>>`"$log`"", $wait,
            "echo edited by $Name>>`"%~$ArgIndex`"", "exit /b $ExitCode")
    }
    else {
        $path = Join-Path $stubs $Name
        Set-Content -LiteralPath $path -Value @(
            '#!/bin/sh', "echo `"$Name `$*`" >> '$log'", "sleep $Delay",
            "echo `"edited by $Name`" >> `"`$$ArgIndex`"", "exit $ExitCode")
        chmod +x $path
    }
}

function Remove-Stub([string]$Name) {
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $stubs $Name), (Join-Path $stubs "$Name.cmd")
}

# Invoke-CcEdit ENV ARGS [INPUT]: run cc-edit.ps1 in a child process with a
# clean HOME and PATH; return @{ Code; Output }.
function Invoke-CcEdit([hashtable]$Env, [string[]]$Arguments, [string]$InputText = '') {
    # Clear every variable bin/cc-edit.ps1 reads, so the caller's shell cannot leak in.
    $vars = @{
        HOME = $homeDir; USERPROFILE = $homeDir; PATH = "$stubs$sep$systemPath"; EDITOR = $null
        CC_EDIT_EDITOR = $null; CC_EDIT_CONFIG = $null; CC_EDIT_DIR = $null
        CC_EDIT_PROFILE = $null; CC_EDIT_KEEP = $null
    }
    foreach ($k in $Env.Keys) { $vars[$k] = $Env[$k] }
    $saved = @{}
    foreach ($k in $vars.Keys) {
        $saved[$k] = [Environment]::GetEnvironmentVariable($k)
        [Environment]::SetEnvironmentVariable($k, $vars[$k])
    }
    try {
        # Windows PowerShell 5.1 turns redirected native stderr into error
        # records, which 'Stop' would make terminating; keep them as text.
        $ErrorActionPreference = 'Continue'
        $out = $InputText | & $psExe -NoProfile -ExecutionPolicy Bypass -File $ccEdit @Arguments 2>&1 |
            ForEach-Object { "$_" } | Out-String
        return @{ Code = $LASTEXITCODE; Output = $out }
    }
    finally {
        foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
    }
}

# Edit-Prompt ENV [INPUT]: edit a fresh prompt; return the editor log.
function Edit-Prompt([hashtable]$Env = @{}, [string]$InputText = '') {
    Set-Content -LiteralPath $log -Value $null
    Set-Content -LiteralPath $prompt -Value 'edit me'
    $script:last = Invoke-CcEdit $Env @($prompt) $InputText
    if ($script:last.Code -ne 0) { throw "cc-edit exited $($script:last.Code): $($script:last.Output)" }
    return (Get-Content -LiteralPath $log | Where-Object { $_ }) -join "`n"
}

function Assert-Like([string]$Name, [string]$Actual, [string]$Pattern) {
    if ($Actual -notlike $Pattern) { throw "FAIL: ${Name}: got '$Actual', want '$Pattern'" }
    Write-Host "ok   $Name"
}

try {
    New-Stub code 5      # code --new-window --wait --profile scratch FILE
    New-Stub notepad 1   # returns at once, like Windows 11 Notepad
    New-Stub editor 1

    # Default: VS Code, new window, scratch profile; draft kept; edit written back.
    Assert-Like 'default is code' (Edit-Prompt) "code --new-window --wait --profile scratch *$([IO.Path]::GetFileName($drafts))*.md"
    Assert-Like 'edit written back' (Get-Content -LiteralPath $prompt)[-1] 'edited by code'
    $draft = Get-ChildItem -LiteralPath $drafts -Filter '*.md' | Select-Object -First 1
    if ((Get-Content -Raw -LiteralPath $draft.FullName) -ne (Get-Content -Raw -LiteralPath $prompt)) { throw 'FAIL: draft differs' }
    Write-Host 'ok   draft persisted'

    # -Config -Editor validates and saves.
    $r = Invoke-CcEdit @{} @('-Config', '-Editor', 'notepad')
    Assert-Like 'config saved' (Get-Content -Raw -LiteralPath $conf) '*editor=notepad*'
    $r = Invoke-CcEdit @{} @('-Config', '-Editor', 'notepad')
    Assert-Like 'one line per key' (@(Get-Content -LiteralPath $conf | Where-Object { $_ -like 'editor=*' }).Count) '1'
    $r = Invoke-CcEdit @{} @('-Config', '-Editor', 'textedit')
    Assert-Like 'invalid editor rejected' $r.Code '2'
    Assert-Like 'config unchanged' (Get-Content -Raw -LiteralPath $conf) '*editor=notepad*'

    # Notepad that returns at once: cc-edit asks for Enter before reading back.
    Assert-Like 'notepad' (Edit-Prompt @{} "`n") 'notepad *.md*'
    Assert-Like 'early-return prompt' $script:last.Output '*press Enter*'
    Assert-Like 'notepad edit written back' (Get-Content -LiteralPath $prompt)[-1] 'edited by notepad'

    # Notepad that blocks until closed: no prompt.
    New-Stub notepad 1 4
    $null = Edit-Prompt
    if ($script:last.Output -like '*press Enter*') { throw 'FAIL: prompt shown for a blocking Notepad' }
    Write-Host 'ok   no prompt for a blocking Notepad'

    # Interactive -Config: choose 1 (code).
    $r = Invoke-CcEdit @{} @('-Config') "1`n"
    Assert-Like 'menu shown' $r.Output '*1) code*'
    Assert-Like 'menu choice saved' (Get-Content -Raw -LiteralPath $conf) '*editor=code*'

    # Interactive -Config: Enter replaces an invalid saved value with code.
    Set-Content -LiteralPath $conf -Value 'editor=gedit'
    $r = Invoke-CcEdit @{} @('-Config') "`n"
    Assert-Like 'invalid saved value noted' $r.Output "*saved editor 'gedit' is not valid here*"
    Assert-Like 'Enter picks code' (Get-Content -Raw -LiteralPath $conf) '*editor=code*'

    # The env var overrides the config file; -Show reports it.
    Assert-Like 'CC_EDIT_EDITOR override' (Edit-Prompt @{ CC_EDIT_EDITOR = 'notepad' }) 'notepad *'
    $r = Invoke-CcEdit @{ CC_EDIT_EDITOR = 'notepad' } @('-Show')
    Assert-Like '-Show' $r.Output '*editor=notepad*CC_EDIT_EDITOR*this terminal uses: notepad*'

    # A hand-edited, invalid value falls back to code with a warning.
    Set-Content -LiteralPath $conf -Value 'editor=gedit'
    Assert-Like 'invalid config value' (Edit-Prompt) 'code *'
    Assert-Like 'invalid value warning' $script:last.Output "*unknown editor 'gedit'*"

    # code missing: $env:EDITOR is used.
    Remove-Stub code
    Assert-Like 'fallback to EDITOR' (Edit-Prompt @{ EDITOR = 'editor' }) 'editor *'
    Assert-Like 'fallback warning' $script:last.Output '*code is not available here*'
    $r = Invoke-CcEdit @{ EDITOR = 'editor' } @('-Show')
    Assert-Like '-Show fallback' $r.Output '*this terminal uses: editor (fallback: code is not available here)*'

    # A failing editor: exit code propagates, prompt untouched.
    New-Stub code 5 0 3
    Set-Content -LiteralPath $prompt -Value 'keep'
    $r = Invoke-CcEdit @{} @($prompt)
    Assert-Like 'editor exit code' $r.Code '3'
    Assert-Like 'prompt untouched' (Get-Content -LiteralPath $prompt) 'keep'
    New-Stub code 5

    # Drafts older than the retention period are pruned; a value that is not
    # a number prunes nothing, and 0 keeps today's drafts.
    $old = Join-Path $drafts 'old.md'
    Set-Content -LiteralPath $old -Value 'old'
    (Get-Item -LiteralPath $old).LastWriteTime = (Get-Date).AddDays(-800)
    $null = Edit-Prompt @{ CC_EDIT_KEEP = 'forever' }
    if (-not (Test-Path -LiteralPath $old)) { throw 'FAIL: CC_EDIT_KEEP=forever pruned a draft' }
    Assert-Like 'bad CC_EDIT_KEEP warning' $script:last.Output "*CC_EDIT_KEEP='forever' is not a number*"
    $null = Edit-Prompt
    if (Test-Path -LiteralPath $old) { throw 'FAIL: old draft not pruned' }
    Write-Host 'ok   old drafts pruned'
    $null = Edit-Prompt @{ CC_EDIT_KEEP = '0' }
    if (-not (Get-ChildItem -LiteralPath $drafts -Filter '*.md')) { throw "FAIL: CC_EDIT_KEEP=0 pruned today's drafts" }
    Write-Host "ok   CC_EDIT_KEEP=0 keeps today's drafts"

    # No arguments: usage, exit 2.
    Assert-Like 'usage' (Invoke-CcEdit @{} @()).Code '2'

    # inc/claude.ps1: VISUAL is set for claude only and restored; cc-edit forwards.
    $fake = Join-Path $testRoot 'fake'
    New-Item -ItemType Directory -Force -Path $fake | Out-Null
    # The fake claude prints each argument in brackets, so 'a b' must arrive as one.
    if ($onWindows) {
        Set-Content -LiteralPath (Join-Path $fake 'claude.cmd') -Encoding ASCII -Value '@echo child VISUAL=%VISUAL% args=[%~1][%~2]'
    }
    else {
        Set-Content -LiteralPath (Join-Path $fake 'claude') -Value @(
            '#!/bin/sh', 'printf "child VISUAL=%s args=" "$VISUAL"', 'printf "[%s]" "$@"', 'echo')
        chmod +x (Join-Path $fake 'claude')
    }
    $savedPath = $env:PATH
    $savedVisual = $env:VISUAL
    try {
        $env:PATH = "$fake$sep$env:PATH"
        $env:VISUAL = 'vim'
        . (Join-Path $repoRoot 'inc/claude.ps1')
        $out = (claude --foo 'a b') -join "`n"
        Assert-Like 'claude sets VISUAL' $out '*child VISUAL=powershell.exe -NoProfile -ExecutionPolicy Bypass -File *cc-edit.ps1 args=`[--foo`]`[a b`]*'
        Assert-Like 'VISUAL restored' $env:VISUAL 'vim'
        Remove-Item Env:VISUAL
        $null = claude
        if ($null -ne $env:VISUAL) { throw 'FAIL: VISUAL not removed after claude' }
        Write-Host 'ok   unset VISUAL stays unset'
        $out = (cc-edit -Show) -join "`n"
        Assert-Like 'cc-edit function forwards switches' $out '*config file:*'
    }
    finally {
        $env:PATH = $savedPath
        $env:VISUAL = $savedVisual
    }

    Write-Host 'PASS: cc-edit.ps1'
}
finally {
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $testRoot
}
