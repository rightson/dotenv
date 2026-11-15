# Tests for bin/agent-edit.ps1 and inc/claude.ps1. Runs on Windows PowerShell 5.1
# and on PowerShell 7 (Windows, macOS, Linux). Editors are replaced by stubs
# that log their arguments and append a line to the file, so no GUI is needed.
#
#   powershell -NoProfile -File tests\test_agent_edit.ps1
#   pwsh -NoProfile -File tests/test_agent_edit.ps1

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
$agentEdit = Join-Path $repoRoot 'bin/agent-edit.ps1'
$psExe = (Get-Process -Id $PID).Path
$onWindows = $env:OS -eq 'Windows_NT'

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("agent-edit-test-" + [guid]::NewGuid())
$stubs = Join-Path $testRoot 'stubs'
$homeDir = Join-Path $testRoot 'home'
$log = Join-Path $testRoot 'editor.log'
$prompt = Join-Path $testRoot 'prompt.md'
$conf = Join-Path $homeDir '.config/agent-edit/config'
$drafts = Join-Path $homeDir '.agent-prompts'
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

# Invoke-AgentEdit ENV ARGS [INPUT]: run agent-edit.ps1 in a child process with a
# clean HOME and PATH; return @{ Code; Output }.
function Invoke-AgentEdit([hashtable]$Env, [string[]]$Arguments, [string]$InputText = '') {
    # Clear every variable bin/agent-edit.ps1 reads, so the caller's shell cannot leak in.
    $vars = @{
        HOME = $homeDir; USERPROFILE = $homeDir; PATH = "$stubs$sep$systemPath"; EDITOR = $null
        AGENT_EDIT_EDITOR = $null; AGENT_EDIT_CONFIG = $null; AGENT_EDIT_DIR = $null
        AGENT_EDIT_PROFILE = $null; AGENT_EDIT_KEEP = $null
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
        $out = $InputText | & $psExe -NoProfile -ExecutionPolicy Bypass -File $agentEdit @Arguments 2>&1 |
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
    $script:last = Invoke-AgentEdit $Env @($prompt) $InputText
    if ($script:last.Code -ne 0) { throw "agent-edit exited $($script:last.Code): $($script:last.Output)" }
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

    # Default: Notepad; draft kept; edit written back. Notepad that returns at
    # once makes agent-edit ask for Enter before reading back.
    Assert-Like 'default is notepad' (Edit-Prompt @{} "`n") "notepad *$([IO.Path]::GetFileName($drafts))*.md*"
    Assert-Like 'edit written back' (Get-Content -LiteralPath $prompt)[-1] 'edited by notepad'
    $draft = Get-ChildItem -LiteralPath $drafts -Filter '*.md' | Select-Object -First 1
    if ((Get-Content -Raw -LiteralPath $draft.FullName) -ne (Get-Content -Raw -LiteralPath $prompt)) { throw 'FAIL: draft differs' }
    Write-Host 'ok   draft persisted'

    # VS Code is selected through the config file.
    # -Config -Editor validates and saves.
    $r = Invoke-AgentEdit @{} @('-Config', '-Editor', 'code')
    Assert-Like 'config saved' (Get-Content -Raw -LiteralPath $conf) '*editor=code*'
    Assert-Like 'editor=code' (Edit-Prompt) "code --new-window --wait --profile scratch *$([IO.Path]::GetFileName($drafts))*.md"
    Assert-Like 'editor=code written back' (Get-Content -LiteralPath $prompt)[-1] 'edited by code'
    $r = Invoke-AgentEdit @{} @('-Config', '-Editor', 'code')
    Assert-Like 'one line per key' (@(Get-Content -LiteralPath $conf | Where-Object { $_ -like 'editor=*' }).Count) '1'
    foreach ($bad in 'textedit', 'textmate') {
        $r = Invoke-AgentEdit @{} @('-Config', '-Editor', $bad)
        Assert-Like "invalid editor $bad rejected" $r.Code '2'
    }
    Assert-Like 'config unchanged' (Get-Content -Raw -LiteralPath $conf) '*editor=code*'
    Remove-Item -Force $conf
    $r = Invoke-AgentEdit @{} @('-Config', '-Editor', 'notepad')
    Assert-Like 'editor=notepad saved' (Get-Content -Raw -LiteralPath $conf) '*editor=notepad*'

    # Notepad that returns at once: agent-edit asks for Enter before reading back.
    Assert-Like 'notepad' (Edit-Prompt @{} "`n") 'notepad *.md*'
    Assert-Like 'early-return prompt' $script:last.Output '*press Enter*'
    Assert-Like 'notepad edit written back' (Get-Content -LiteralPath $prompt)[-1] 'edited by notepad'

    # Notepad that blocks until closed: no prompt.
    New-Stub notepad 1 4
    $null = Edit-Prompt
    if ($script:last.Output -like '*press Enter*') { throw 'FAIL: prompt shown for a blocking Notepad' }
    Write-Host 'ok   no prompt for a blocking Notepad'

    # Interactive -Config: choose 2 (code).
    $r = Invoke-AgentEdit @{} @('-Config') "2`n"
    Assert-Like 'menu shown' $r.Output '*1) notepad*'
    Assert-Like 'menu choice saved' (Get-Content -Raw -LiteralPath $conf) '*editor=code*'

    # Interactive -Config: Enter replaces an invalid saved value with the default.
    Set-Content -LiteralPath $conf -Value 'editor=textedit'
    $r = Invoke-AgentEdit @{} @('-Config') "`n"
    Assert-Like 'invalid saved value noted' $r.Output "*saved editor 'textedit' is not valid here*"
    Assert-Like 'Enter picks the default' (Get-Content -Raw -LiteralPath $conf) '*editor=notepad*'

    # The env var overrides the config file; -Show reports it.
    Assert-Like 'AGENT_EDIT_EDITOR override' (Edit-Prompt @{ AGENT_EDIT_EDITOR = 'code' }) 'code *'
    $r = Invoke-AgentEdit @{ AGENT_EDIT_EDITOR = 'code' } @('-Show')
    Assert-Like '-Show' $r.Output '*editor=code*AGENT_EDIT_EDITOR*this terminal uses: code*'

    # A hand-edited, invalid value falls back to the default (Notepad) with a warning.
    Set-Content -LiteralPath $conf -Value 'editor=textedit'
    Assert-Like 'invalid config value' (Edit-Prompt @{} "`n") 'notepad *'
    Assert-Like 'invalid value warning' $script:last.Output "*unknown editor 'textedit'*using notepad*"
    $r = Invoke-AgentEdit @{} @('-Show')
    Assert-Like '-Show flags an invalid value' $r.Output '*editor=textedit*invalid; notepad is used*'

    # The selected editor missing: $env:EDITOR is used.
    Set-Content -LiteralPath $conf -Value 'editor=code'
    Remove-Stub code
    Assert-Like 'fallback to EDITOR' (Edit-Prompt @{ EDITOR = 'editor' }) 'editor *'
    Assert-Like 'fallback warning' $script:last.Output '*code is not available here*'
    $r = Invoke-AgentEdit @{ EDITOR = 'editor' } @('-Show')
    Assert-Like '-Show fallback' $r.Output '*this terminal uses: editor (fallback: code is not available here)*'
    Remove-Item -Force $conf
    New-Stub code 5

    # A failing editor: exit code propagates, prompt untouched.
    Set-Content -LiteralPath $conf -Value 'editor=code'
    New-Stub code 5 0 3
    Set-Content -LiteralPath $prompt -Value 'keep'
    $r = Invoke-AgentEdit @{} @($prompt)
    Assert-Like 'editor exit code' $r.Code '3'
    Assert-Like 'prompt untouched' (Get-Content -LiteralPath $prompt) 'keep'
    New-Stub code 5
    Remove-Item -Force $conf

    # Drafts older than the retention period are pruned; a value that is not
    # a number prunes nothing, and 0 keeps today's drafts.
    $old = Join-Path $drafts 'old.md'
    Set-Content -LiteralPath $old -Value 'old'
    (Get-Item -LiteralPath $old).LastWriteTime = (Get-Date).AddDays(-800)
    $null = Edit-Prompt @{ AGENT_EDIT_KEEP = 'forever' } "`n"
    if (-not (Test-Path -LiteralPath $old)) { throw 'FAIL: AGENT_EDIT_KEEP=forever pruned a draft' }
    Assert-Like 'bad AGENT_EDIT_KEEP warning' $script:last.Output "*AGENT_EDIT_KEEP='forever' is not a number*"
    $null = Edit-Prompt @{} "`n"
    if (Test-Path -LiteralPath $old) { throw 'FAIL: old draft not pruned' }
    Write-Host 'ok   old drafts pruned'
    $null = Edit-Prompt @{ AGENT_EDIT_KEEP = '0' } "`n"
    if (-not (Get-ChildItem -LiteralPath $drafts -Filter '*.md')) { throw "FAIL: AGENT_EDIT_KEEP=0 pruned today's drafts" }
    Write-Host "ok   AGENT_EDIT_KEEP=0 keeps today's drafts"

    # Drafts folder migration (~\.claude-prompts -> ~\.agent-prompts).
    $oldDrafts = Join-Path $homeDir '.claude-prompts'
    $custom = Join-Path $testRoot 'custom'
    function Reset-Drafts { Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $drafts, $oldDrafts, $custom }

    Reset-Drafts
    New-Item -ItemType Directory -Force -Path $oldDrafts | Out-Null
    Set-Content -LiteralPath (Join-Path $oldDrafts 'kept.md') -Value 'old'
    $null = Edit-Prompt @{} "`n"
    if (-not (Test-Path -LiteralPath (Join-Path $drafts 'kept.md')) -or (Test-Path -LiteralPath $oldDrafts)) { throw 'FAIL: old drafts folder not migrated' }
    Assert-Like 'migration notice' $script:last.Output '*moved*.claude-prompts to*'

    Reset-Drafts
    New-Item -ItemType Directory -Force -Path $oldDrafts | Out-Null
    Set-Content -LiteralPath (Join-Path $oldDrafts 'kept.md') -Value 'old'
    $null = Edit-Prompt @{ AGENT_EDIT_DIR = $custom } "`n"
    if (-not (Test-Path -LiteralPath (Join-Path $oldDrafts 'kept.md')) -or (Test-Path -LiteralPath $drafts)) { throw 'FAIL: migrated although AGENT_EDIT_DIR is set' }
    Write-Host 'ok   no migration with AGENT_EDIT_DIR'

    Reset-Drafts
    New-Item -ItemType Directory -Force -Path $oldDrafts, $drafts | Out-Null
    Set-Content -LiteralPath (Join-Path $oldDrafts 'kept.md') -Value 'old'
    $null = Edit-Prompt @{} "`n"
    if (-not (Test-Path -LiteralPath (Join-Path $oldDrafts 'kept.md')) -or (Test-Path -LiteralPath (Join-Path $drafts 'kept.md'))) { throw 'FAIL: migrated onto an existing new folder' }
    Write-Host 'ok   no migration when the new folder exists'

    # No arguments: usage, exit 2.
    Assert-Like 'usage' (Invoke-AgentEdit @{} @()).Code '2'

    # inc/claude.ps1: VISUAL is set for claude and codex only and restored; agent-edit forwards.
    $fake = Join-Path $testRoot 'fake'
    New-Item -ItemType Directory -Force -Path $fake | Out-Null
    # The fake claude prints each argument in brackets, so 'a b' must arrive as one.
    if ($onWindows) {
        foreach ($n in 'claude', 'codex') {
            Set-Content -LiteralPath (Join-Path $fake "$n.cmd") -Encoding ASCII -Value '@echo child VISUAL=%VISUAL% args=[%~1][%~2]'
        }
    }
    else {
        foreach ($n in 'claude', 'codex') {
            Set-Content -LiteralPath (Join-Path $fake $n) -Value @(
                '#!/bin/sh', 'printf "child VISUAL=%s args=" "$VISUAL"', 'printf "[%s]" "$@"', 'echo')
            chmod +x (Join-Path $fake $n)
        }
    }
    $savedPath = $env:PATH
    $savedVisual = $env:VISUAL
    try {
        $env:PATH = "$fake$sep$env:PATH"
        $env:VISUAL = 'vim'
        . (Join-Path $repoRoot 'inc/claude.ps1')
        $out = (claude --foo 'a b') -join "`n"
        Assert-Like 'claude sets VISUAL' $out '*child VISUAL=powershell.exe -NoProfile -ExecutionPolicy Bypass -File *agent-edit.ps1 args=`[--foo`]`[a b`]*'
        Assert-Like 'VISUAL restored' $env:VISUAL 'vim'
        $out = (codex --foo 'a b') -join "`n"
        Assert-Like 'codex sets VISUAL' $out '*child VISUAL=powershell.exe -NoProfile -ExecutionPolicy Bypass -File *agent-edit.ps1 args=`[--foo`]`[a b`]*'
        Assert-Like 'VISUAL restored after codex' $env:VISUAL 'vim'
        Remove-Item Env:VISUAL
        $null = claude
        if ($null -ne $env:VISUAL) { throw 'FAIL: VISUAL not removed after claude' }
        Write-Host 'ok   unset VISUAL stays unset'
        $out = (agent-edit -Show) -join "`n"
        Assert-Like 'agent-edit function forwards switches' $out '*config file:*'
    }
    finally {
        $env:PATH = $savedPath
        $env:VISUAL = $savedVisual
    }

    Write-Host 'PASS: agent-edit.ps1'
}
finally {
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $testRoot
}
