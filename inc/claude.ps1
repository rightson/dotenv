# Coding-agent helpers for PowerShell (dot-sourced from $PROFILE by dotenv.ps1).

# Run coding agent $Name (claude, codex) with Ctrl+G prompts opened via
# bin\agent-edit.ps1; the global VISUAL is left untouched. The agents split
# $VISUAL on spaces and run it without a shell, so the editor command must
# start with an .exe and the script path must not contain spaces (the 8.3
# short path is used if it does).
function Invoke-Agent([string]$Name, [object[]]$AgentArgs) {
    $exe = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $exe) {
        Write-Error "${Name}: executable not found on PATH"
        return
    }

    # $PSScriptRoot is this file's directory (inc), even inside a function.
    $agentEdit = Join-Path (Split-Path $PSScriptRoot -Parent) 'bin\agent-edit.ps1'
    if ($agentEdit.Contains(' ')) {
        try { $agentEdit = (New-Object -ComObject Scripting.FileSystemObject).GetFile($agentEdit).ShortPath }
        catch { Write-Verbose "no 8.3 short path for ${agentEdit}: $_" }
    }
    if ($agentEdit.Contains(' ')) {
        Write-Warning "agent-edit disabled, path contains spaces: $agentEdit"
        & $exe.Source @AgentArgs
        return
    }

    $saved = $env:VISUAL
    $env:VISUAL = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File $agentEdit"
    try {
        & $exe.Source @AgentArgs
    }
    finally {
        $env:VISUAL = $saved
    }
}

function claude { Invoke-Agent 'claude' $args }
function codex { Invoke-Agent 'codex' $args }

# agent-edit settings from PowerShell: agent-edit -Config, agent-edit -Show.
function agent-edit {
    & (Join-Path (Split-Path $PSScriptRoot -Parent) 'bin\agent-edit.ps1') @args
}
