# agent-edit.ps1: external editor for coding agents (Claude Code, Codex, ...) on Windows.
#
# PowerShell port of bin/agent-edit. Copies the agent's temp prompt file into a
# persistent drafts folder, opens the copy in the configured editor, waits
# until editing is done, then copies the result back.
#
# The agents split $VISUAL on spaces and runs it without a shell, so a .ps1
# cannot be $VISUAL directly; inc/claude.ps1 sets
#   VISUAL=powershell.exe -NoProfile -ExecutionPolicy Bypass -File <this file>
#
# Usage:
#   agent-edit.ps1 <file>                 edit <file> (what the agent runs)
#   agent-edit.ps1 -Config                choose the editor interactively
#   agent-edit.ps1 -Config -Editor NAME   set the editor (notepad or code)
#   agent-edit.ps1 -Show                  print the settings
#
# Settings (the env var overrides the config file; the default is notepad):
#   editor  AGENT_EDIT_EDITOR  notepad  Notepad (default)
#                           code     VS Code, new window, scratch profile
#
# Other env overrides:
#   AGENT_EDIT_CONFIG   config file    (default: ~\.config\agent-edit\config)
#   AGENT_EDIT_DIR      drafts folder  (default: ~\.agent-prompts)
#   AGENT_EDIT_PROFILE  VS Code profile for editor=code (default: scratch)
#   AGENT_EDIT_KEEP     draft retention in days (default: 730, i.e. 2 years;
#                    not a number: no pruning)
#
# An editor that is not available falls back to $env:EDITOR, then notepad.
#
# Keep this script compatible with Windows PowerShell 5.1.

param(
    [Parameter(Position = 0)][string]$Path,
    [switch]$Config,
    [string]$Editor,
    [switch]$Show
)

$ConfPath = if ($env:AGENT_EDIT_CONFIG) { $env:AGENT_EDIT_CONFIG } else { Join-Path $HOME '.config\agent-edit\config' }
$DraftDir = if ($env:AGENT_EDIT_DIR) { $env:AGENT_EDIT_DIR } else { Join-Path $HOME '.agent-prompts' }
$ProfileName = if ($env:AGENT_EDIT_PROFILE) { $env:AGENT_EDIT_PROFILE } else { 'scratch' }
$KeepDays = 730
if ($env:AGENT_EDIT_KEEP -and -not [int]::TryParse($env:AGENT_EDIT_KEEP, [ref]$KeepDays)) {
    $KeepDays = -1   # not a number: do not prune (see Invoke-Edit)
}

$DefaultEditor = 'notepad'
$Editors = @('notepad', 'code')
$Descriptions = @{
    notepad = 'Notepad'
    code    = "VS Code, new window with the '$ProfileName' profile"
}

function Write-Note([string]$Message) {
    [Console]::Error.WriteLine("agent-edit: $Message")
}

# --- settings ---------------------------------------------------------------

# Last value of $Key in the config file, or $null.
function Get-ConfValue([string]$Key) {
    if (-not (Test-Path -LiteralPath $ConfPath)) { return $null }
    $value = $null
    foreach ($line in Get-Content -LiteralPath $ConfPath) {
        if ($line -match "^\s*$Key\s*=\s*([^\s#]*)") { $value = $Matches[1] }
    }
    return $value
}

# Replace $Key in the config file.
function Set-ConfValue([string]$Key, [string]$Value) {
    New-Item -ItemType Directory -Force -Path (Split-Path $ConfPath -Parent) | Out-Null
    if (Test-Path -LiteralPath $ConfPath) {
        $lines = @(Get-Content -LiteralPath $ConfPath | Where-Object { $_ -notmatch "^\s*$Key\s*=" })
    }
    else {
        $lines = @('# agent-edit settings; run: agent-edit.ps1 -Config')
    }
    $lines += "$Key=$Value"
    Set-Content -LiteralPath $ConfPath -Value $lines -Encoding ASCII
}

# Effective editor setting: env var, config file, then the default.
function Get-EditorSetting {
    $value = $env:AGENT_EDIT_EDITOR
    if (-not $value) { $value = Get-ConfValue 'editor' }
    if (-not $value) { $value = $DefaultEditor }
    return $value
}

# --- editors ----------------------------------------------------------------

# Full path of program $Name on PATH, or $null.
function Find-Program([string]$Name) {
    $cmd = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    return $null
}

function Test-Editor([string]$Name) {
    if ($Editors -notcontains $Name) { return $false }
    return [bool](Find-Program $Name)
}

# Editor to use: one of $Editors, or "fallback" for $env:EDITOR. When the
# setting cannot be used, $script:FallbackReason says why.
function Resolve-Editor {
    $script:FallbackReason = $null
    $want = Get-EditorSetting
    if ($Editors -notcontains $want) {
        Write-Note "unknown editor '$want' (choose from: $($Editors -join ' ')); using $DefaultEditor"
        $want = $DefaultEditor
    }
    if (Test-Editor $want) { return $want }
    $script:FallbackReason = "$want is not available here"
    if ($env:EDITOR) {
        Write-Note "$script:FallbackReason; using $env:EDITOR"
        return 'fallback'
    }
    Write-Note "$script:FallbackReason; using notepad"
    return 'notepad'
}

# Open $File in editor $Name, wait until editing is done; return the exit code.
function Invoke-Editor([string]$Name, [string]$File) {
    switch ($Name) {
        'code' {
            Write-Note 'opened in VS Code; save, then close the tab to return'
            & code --new-window --wait --profile $ProfileName $File | Out-Host
            return $LASTEXITCODE
        }
        'notepad' {
            # Start-Process -Wait, because PowerShell does not wait for GUI
            # programs started with &.
            Write-Note 'opened in Notepad; save, then close it to return'
            $start = Get-Date
            $proc = Start-Process -FilePath (Find-Program notepad) -ArgumentList "`"$File`"" -Wait -PassThru
            # Windows 11 Notepad hands the file to its packaged app, or to an
            # already open window as a tab, and returns at once.
            if (((Get-Date) - $start).TotalSeconds -lt 3) {
                Read-Host 'Notepad returned before you finished. Save the file in Notepad, then press Enter here' | Out-Null
            }
            return $proc.ExitCode
        }
        'fallback' {
            $exe = Find-Program $env:EDITOR
            if (-not $exe) { $exe = $env:EDITOR }
            $proc = Start-Process -FilePath $exe -ArgumentList "`"$File`"" -NoNewWindow -Wait -PassThru
            return $proc.ExitCode
        }
    }
    return 1
}

# --- commands ---------------------------------------------------------------

function Show-Settings {
    Write-Output "config file: $ConfPath"
    $line = "editor=$(Get-EditorSetting)  (options: $($Editors -join ' '))"
    if ($env:AGENT_EDIT_EDITOR) { $line += '  [from AGENT_EDIT_EDITOR]' }
    if ($Editors -notcontains (Get-EditorSetting)) { $line += "  [invalid; $DefaultEditor is used]" }
    Write-Output $line
    $name = Resolve-Editor
    if ($name -eq 'fallback') { $name = $env:EDITOR }
    if ($script:FallbackReason) { $name += " (fallback: $script:FallbackReason)" }
    Write-Output "this terminal uses: $name"
}

# Choose and save the editor; return the exit code. Prints to the host only,
# so the return value is the only pipeline output.
function Invoke-Configure([string]$Choice) {
    if (-not $Choice) {
        # Enter keeps the saved value, or picks the default when none (or an invalid
        # one) is saved.
        Write-Host 'Ctrl+G editor for coding agents (Windows):'
        $current = Get-ConfValue 'editor'
        if ($current -and $Editors -notcontains $current) {
            Write-Host "  (the saved editor '$current' is not valid here)"
            $current = $null
        }
        if (-not $current) { $current = $DefaultEditor }
        for ($i = 0; $i -lt $Editors.Count; $i++) {
            $name = $Editors[$i]
            $mark = ''
            if ($name -eq $current) { $mark += ' (current)' }
            if (-not (Test-Editor $name)) { $mark += ' (not available here)' }
            Write-Host ('  {0}) {1,-8} {2}{3}' -f ($i + 1), $name, $Descriptions[$name], $mark)
        }
        while (-not $choice) {
            $answer = Read-Host "Choose 1-$($Editors.Count) (Enter keeps $current)"
            $n = 0
            if (-not $answer) { $choice = $current }
            elseif ([int]::TryParse($answer, [ref]$n) -and $n -ge 1 -and $n -le $Editors.Count) { $choice = $Editors[$n - 1] }
            elseif ($Editors -contains $answer) { $choice = $answer }
            else { Write-Host "  invalid choice: $answer" }
        }
    }
    if ($Editors -notcontains $choice) {
        Write-Note "invalid editor '$choice' (choose from: $($Editors -join ' '))"
        return 2
    }
    Set-ConfValue 'editor' $choice
    if ($env:AGENT_EDIT_EDITOR) { Write-Note "note: AGENT_EDIT_EDITOR is set and overrides editor in $ConfPath" }
    Write-Host "Saved to $ConfPath"
    Show-Settings | Out-Host
    return 0
}

# With the default drafts folder, move the old default (~\.claude-prompts) to
# the new one the first time.
function Move-OldDrafts {
    if ($env:AGENT_EDIT_DIR) { return }
    $old = Join-Path $HOME '.claude-prompts'
    if ((Test-Path -LiteralPath $DraftDir) -or -not (Test-Path -LiteralPath $old)) { return }
    try {
        Move-Item -LiteralPath $old -Destination $DraftDir -ErrorAction Stop
        Write-Note "moved $old to $DraftDir"
    }
    catch {
        Write-Note "could not move $old to $DraftDir; using $DraftDir"
    }
}

# Edit $File through a draft copy; return the exit code.
function Invoke-Edit([string]$File) {
    $name = Resolve-Editor
    Move-OldDrafts
    New-Item -ItemType Directory -Force -Path $DraftDir | Out-Null
    $dst = Join-Path $DraftDir ('{0}-{1}.md' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $PID)

    Copy-Item -LiteralPath $File -Destination $dst
    $rc = Invoke-Editor $name $dst
    if ($rc -ne 0) { return $rc }
    Copy-Item -LiteralPath $dst -Destination $File

    # Prune drafts not modified for more than $KeepDays days, counted in whole
    # days like `find -mtime +N` in bin/agent-edit (so 0 keeps today's drafts).
    if ($KeepDays -lt 0) {
        Write-Note "AGENT_EDIT_KEEP='$env:AGENT_EDIT_KEEP' is not a number of days; not pruning drafts"
        return 0
    }
    $cutoff = (Get-Date).AddDays(-($KeepDays + 1))
    Get-ChildItem -LiteralPath $DraftDir -Filter '*.md' -File |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        Remove-Item -Force -ErrorAction SilentlyContinue
    return 0
}

$ErrorActionPreference = 'Stop'
try {
    if ($Config) { exit (Invoke-Configure $Editor) }
    if ($Show) { Show-Settings; exit 0 }
    if (-not $Path) {
        [Console]::Error.WriteLine('Usage: agent-edit.ps1 <file> | -Config [-Editor notepad|code] | -Show')
        exit 2
    }
    exit (Invoke-Edit $Path)
}
catch {
    Write-Note $_.Exception.Message
    exit 1
}
