# cc-edit.ps1: external editor for Claude Code (Ctrl+G) on Windows.
#
# PowerShell port of bin/cc-edit. Copies Claude Code's temp prompt file into a
# persistent drafts folder, opens it in a disposable VS Code window, then
# copies the result back. Falls back to $env:EDITOR (or notepad) when the
# `code` CLI is not available.
#
# Claude Code splits $VISUAL on spaces and runs it without a shell, so a .ps1
# cannot be $VISUAL directly; inc/claude.ps1 sets
#   VISUAL=powershell.exe -NoProfile -ExecutionPolicy Bypass -File <this file>
#
# Usage: cc-edit.ps1 <file>
#
# Env overrides:
#   CC_EDIT_DIR      drafts folder        (default: ~\.claude-prompts)
#   CC_EDIT_PROFILE  VS Code profile name (default: scratch)
#   CC_EDIT_KEEP     retention in days    (default: 730, i.e. 2 years)

param([string]$Path)

if (-not $Path) {
    [Console]::Error.WriteLine('Usage: cc-edit.ps1 <file>')
    exit 2
}

$ErrorActionPreference = 'Stop'

$dir = if ($env:CC_EDIT_DIR) { $env:CC_EDIT_DIR } else { Join-Path $HOME '.claude-prompts' }
$profileName = if ($env:CC_EDIT_PROFILE) { $env:CC_EDIT_PROFILE } else { 'scratch' }
$keepDays = if ($env:CC_EDIT_KEEP) { [int]$env:CC_EDIT_KEEP } else { 730 }

# No VS Code CLI: edit the original file in place. Start-Process -Wait also
# blocks for GUI editors such as notepad, which `&` would not wait for.
if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    $editor = if ($env:EDITOR) { $env:EDITOR } else { 'notepad' }
    $proc = Start-Process -FilePath $editor -ArgumentList "`"$Path`"" -NoNewWindow -Wait -PassThru
    exit $proc.ExitCode
}

try {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $dst = Join-Path $dir ('{0}-{1}.md' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $PID)

    Copy-Item -LiteralPath $Path -Destination $dst
    & code --new-window --wait --profile $profileName $dst
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Copy-Item -LiteralPath $dst -Destination $Path

    # Prune drafts not modified for more than $keepDays days.
    $cutoff = (Get-Date).AddDays(-$keepDays)
    Get-ChildItem -LiteralPath $dir -Filter '*.md' -File |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}
catch {
    [Console]::Error.WriteLine("cc-edit: $($_.Exception.Message)")
    exit 1
}

exit 0
