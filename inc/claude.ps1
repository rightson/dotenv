# Claude Code helpers for PowerShell (dot-sourced from $PROFILE by dotenv.ps1).

# Claude Code only: open Ctrl+G prompts via bin\cc-edit.ps1; the global VISUAL
# is left untouched. Claude Code splits $VISUAL on spaces and runs it without
# a shell, so the editor command must start with an .exe and the script path
# must not contain spaces (the 8.3 short path is used if it does).
function claude {
    $exe = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $exe) {
        Write-Error 'claude: executable not found on PATH'
        return
    }

    # $PSScriptRoot is this file's directory (inc), even inside a function.
    $ccEdit = Join-Path (Split-Path $PSScriptRoot -Parent) 'bin\cc-edit.ps1'
    if ($ccEdit.Contains(' ')) {
        try { $ccEdit = (New-Object -ComObject Scripting.FileSystemObject).GetFile($ccEdit).ShortPath }
        catch { Write-Verbose "no 8.3 short path for ${ccEdit}: $_" }
    }
    if ($ccEdit.Contains(' ')) {
        Write-Warning "cc-edit disabled, path contains spaces: $ccEdit"
        & $exe.Source @args
        return
    }

    $saved = $env:VISUAL
    $env:VISUAL = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ccEdit"
    try {
        & $exe.Source @args
    }
    finally {
        $env:VISUAL = $saved
    }
}

# cc-edit settings from PowerShell: cc-edit -Config, cc-edit -Show.
function cc-edit {
    & (Join-Path (Split-Path $PSScriptRoot -Parent) 'bin\cc-edit.ps1') @args
}
