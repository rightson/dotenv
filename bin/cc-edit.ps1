# cc-edit.ps1: external editor for Claude Code (Ctrl+G) on Windows.
#
# PowerShell port of bin/cc-edit. Copies Claude Code's temp prompt file into a
# persistent drafts folder, opens the copy in the configured editor, waits
# until editing is done, then copies the result back.
#
# Claude Code splits $VISUAL on spaces and runs it without a shell, so a .ps1
# cannot be $VISUAL directly; inc/claude.ps1 sets
#   VISUAL=powershell.exe -NoProfile -ExecutionPolicy Bypass -File <this file>
#
# Usage:
#   cc-edit.ps1 <file>                 edit <file> (what Claude Code runs)
#   cc-edit.ps1 -Config                choose the editor interactively
#   cc-edit.ps1 -Config -Editor NAME   set the editor (code or notepad)
#   cc-edit.ps1 -Show                  print the settings
#
# Settings (the env var overrides the config file; the default is code):
#   editor  CC_EDIT_EDITOR  code     VS Code, new window, scratch profile
#                           notepad  Notepad
#
# Other env overrides:
#   CC_EDIT_CONFIG   config file    (default: ~\.config\cc-edit\config)
#   CC_EDIT_DIR      drafts folder  (default: ~\.claude-prompts)
#   CC_EDIT_PROFILE  VS Code profile for editor=code (default: scratch)
#   CC_EDIT_KEEP     draft retention in days (default: 730, i.e. 2 years)
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

$ConfPath = if ($env:CC_EDIT_CONFIG) { $env:CC_EDIT_CONFIG } else { Join-Path $HOME '.config\cc-edit\config' }
$DraftDir = if ($env:CC_EDIT_DIR) { $env:CC_EDIT_DIR } else { Join-Path $HOME '.claude-prompts' }
$ProfileName = if ($env:CC_EDIT_PROFILE) { $env:CC_EDIT_PROFILE } else { 'scratch' }
$KeepDays = if ($env:CC_EDIT_KEEP) { [int]$env:CC_EDIT_KEEP } else { 730 }

$Editors = @('code', 'notepad')
$Descriptions = @{
    code    = "VS Code, new window with the '$ProfileName' profile"
    notepad = 'Notepad'
}

function Write-Note([string]$Message) {
    [Console]::Error.WriteLine("cc-edit: $Message")
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
        $lines = @('# cc-edit settings; run: cc-edit.ps1 -Config')
    }
    $lines += "$Key=$Value"
    Set-Content -LiteralPath $ConfPath -Value $lines -Encoding ASCII
}

# Effective editor setting: env var, config file, then "code".
function Get-EditorSetting {
    $value = $env:CC_EDIT_EDITOR
    if (-not $value) { $value = Get-ConfValue 'editor' }
    if (-not $value) { $value = 'code' }
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

# Editor to use: one of $Editors, or "fallback" for $env:EDITOR.
function Resolve-Editor {
    $want = Get-EditorSetting
    if ($Editors -notcontains $want) {
        Write-Note "unknown editor '$want' (choose from: $($Editors -join ' ')); using code"
        $want = 'code'
    }
    if (Test-Editor $want) { return $want }
    if ($env:EDITOR) {
        Write-Note "$want is not available here; using $env:EDITOR"
        return 'fallback'
    }
    Write-Note "$want is not available here; using notepad"
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
    if ($env:CC_EDIT_EDITOR) { $line += '  [from CC_EDIT_EDITOR]' }
    Write-Output $line
    Write-Output "this terminal uses: $(Resolve-Editor)"
}

# Choose and save the editor; return the exit code. Prints to the host only,
# so the return value is the only pipeline output.
function Invoke-Configure([string]$Choice) {
    if (-not $Choice) {
        $current = Get-EditorSetting
        Write-Host 'Claude Code Ctrl+G editor (Windows):'
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
    if ($env:CC_EDIT_EDITOR) { Write-Note "note: CC_EDIT_EDITOR is set and overrides editor in $ConfPath" }
    Write-Host "Saved to $ConfPath"
    Show-Settings | Out-Host
    return 0
}

# Edit $File through a draft copy; return the exit code.
function Invoke-Edit([string]$File) {
    $name = Resolve-Editor
    New-Item -ItemType Directory -Force -Path $DraftDir | Out-Null
    $dst = Join-Path $DraftDir ('{0}-{1}.md' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $PID)

    Copy-Item -LiteralPath $File -Destination $dst
    $rc = Invoke-Editor $name $dst
    if ($rc -ne 0) { return $rc }
    Copy-Item -LiteralPath $dst -Destination $File

    # Prune drafts not modified for more than $KeepDays days.
    $cutoff = (Get-Date).AddDays(-$KeepDays)
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
        [Console]::Error.WriteLine('Usage: cc-edit.ps1 <file> | -Config [-Editor code|notepad] | -Show')
        exit 2
    }
    exit (Invoke-Edit $Path)
}
catch {
    Write-Note $_.Exception.Message
    exit 1
}
