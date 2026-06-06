# PowerShell Aliases and Functions Equivalent to Provided Shell Aliases

# --- Alias management ---
Set-Alias al Get-Alias
function aliasrc { code $env:ENV_ROOT\inc\aliases.ps1 }  # Use VSCode or change to your editor

# --- Add common parameter ---
# PowerShell function implementations to match shell alias behavior

# mv -i (interactive/prompt before overwrite)
function mv {
    param([Parameter(ValueFromRemainingArguments = $true)]$params)

    # Handle empty params case
    if ($null -eq $params -or $params.Length -lt 2) {
        Write-Error "Usage: mv source destination"
        return
    }

    # Extract source and destination
    $source = $params[0..($params.Length - 2)]
    $destination = $params[-1]

    foreach ($item in $source) {
        # Check if destination exists and prompt
        $destPath = if (Test-Path -Path $destination -PathType Container) {
            Join-Path $destination (Split-Path $item -Leaf)
        }
        else {
            $destination
        }

        if (Test-Path $destPath) {
            $response = Read-Host "Overwrite $destPath? (y/n)"
            if ($response -ne "y") {
                Write-Host "Skipping $item"
                continue
            }
        }
        Move-Item -Path $item -Destination $destination -Force
    }
}

# cp -r (recursive copy)
function cp {
    param([Parameter(ValueFromRemainingArguments = $true)]$params)

    # Handle empty params case
    if ($null -eq $params -or $params.Length -lt 2) {
        Write-Error "Usage: cp source destination"
        return
    }

    # Extract source and destination
    $source = $params[0..($params.Length - 2)]
    $destination = $params[-1]

    foreach ($item in $source) {
        Copy-Item -Path $item -Destination $destination -Recurse -Force
    }
}

# scp -r (recursive secure copy)
function scp {
    param([Parameter(ValueFromRemainingArguments = $true)]$params)

    # Just pass all arguments to scp with -r
    if (Get-Command scp.exe -ErrorAction SilentlyContinue) {
        & scp.exe -r @params
    }
    else {
        Write-Error "scp command not found"
    }
}

# wget -c (continue downloading)
function wget {
    param([Parameter(ValueFromRemainingArguments = $true)]$params)

    # Check if we have wget or should use Invoke-WebRequest
    if (Get-Command wget.exe -ErrorAction SilentlyContinue) {
        & wget.exe -c @params
    }
    else {
        # Handle empty params case
        if ($null -eq $params -or $params.Length -lt 1) {
            Write-Error "Usage: wget URL"
            return
        }

        # Extract URL (assuming it's the last parameter)
        $url = $params[-1]
        $outFile = Split-Path $url -Leaf

        # Check for existing file to implement continue behavior
        if (Test-Path $outFile) {
            $fileSize = (Get-Item $outFile).Length
            $headers = @{"Range" = "bytes=$fileSize-" }
            try {
                Invoke-WebRequest -Uri $url -Headers $headers -OutFile $outFile -Resume
            }
            catch {
                Write-Error "Failed to download: $_"
            }
        }
        else {
            try {
                Invoke-WebRequest -Uri $url -OutFile $outFile
            }
            catch {
                Write-Error "Failed to download: $_"
            }
        }
    }
}

# tree -C (colorized output)
function tree {
    param([Parameter(ValueFromRemainingArguments = $true)]$params)

    if (Get-Command tree.com -ErrorAction SilentlyContinue) {
        # Windows has tree.com
        & tree.com @params
    }
    else {
        # Fallback to PowerShell implementation
        $path = if ($params.Count -gt 0) { $params[0] } else { "." }

        if (-not (Test-Path $path)) {
            Write-Error "Path not found: $path"
            return
        }

        Write-Host "Folder PATH listing for volume $((Get-Item $path).FullName)"
        Write-Host ""

        $items = Get-ChildItem -Path $path -Recurse | Where-Object { $_.PSIsContainer }
        $prevDepth = 0
        $prevPath = ""

        foreach ($item in $items) {
            $relativePath = $item.FullName.Substring((Get-Item $path).FullName.Length)
            $depth = ($relativePath.Split([IO.Path]::DirectorySeparatorChar, [StringSplitOptions]::RemoveEmptyEntries)).Count

            $indent = "    " * ($depth - 1)
            if ($depth -gt 0) {
                Write-Host "$indent├───$($item.Name)"
            }
        }

        Write-Host ""
    }
}

# ls with color support
function ls {
    param([Parameter(ValueFromRemainingArguments = $true)]$params)

    # Parse common ls flags
    $showHidden = $false
    $showDetails = $false
    $path = "."

    foreach ($p in $params) {
        if ($p -match "^-") {
            if ($p.Contains("a") -or $p.Contains("A")) { $showHidden = $true }
            if ($p.Contains("l")) { $showDetails = $true }
        }
        elseif (-not $p.StartsWith("-")) {
            $path = $p
        }
    }

    # Build Get-ChildItem parameters
    $gcParams = @{
        Path = $path
    }

    if ($showHidden) {
        $gcParams.Force = $true
    }

    # Execute with appropriate formatting
    if ($showDetails) {
        Get-ChildItem @gcParams | Format-Table -AutoSize Mode, LastWriteTime, Length, Name
    }
    else {
        Get-ChildItem @gcParams | Format-Wide -AutoSize
    }
}

# grep with color
function grep {
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Pattern,

        [Parameter(ValueFromPipeline = $true)]
        [string]$InputObject,

        [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
        [string[]]$Path
    )

    begin {
        # Check if terminal supports ANSI color codes
        $supportsColor = $Host.UI.SupportsVirtualTerminal -or ($env:TERM -like "*color*")

        # Define colors
        $highlightStart = if ($supportsColor) { "`e[91;103m" } else { "" }
        $highlightEnd = if ($supportsColor) { "`e[0m" } else { "" }
    }

    process {
        if ($InputObject) {
            if ($InputObject -match $Pattern) {
                $result = $InputObject -replace "($Pattern)", "$highlightStart`$1$highlightEnd"
                Write-Output $result
            }
        }
        elseif ($Path) {
            foreach ($file in $Path) {
                if (Test-Path $file -PathType Leaf) {
                    try {
                        $content = Get-Content $file -ErrorAction Stop
                        $lineNum = 0
                        foreach ($line in $content) {
                            $lineNum++
                            if ($line -match $Pattern) {
                                $result = $line -replace "($Pattern)", "$highlightStart`$1$highlightEnd"
                                Write-Output "$file`:$lineNum`:$result"
                            }
                        }
                    }
                    catch {
                        # Fixed error message
                        Write-Error ("Error reading file " + $file + ": " + $_.Exception.Message)
                    }
                }
            }
        }
    }
}

# --- OS-specific aliases ---
if ($IsLinux -or $IsMacOS) {
    Set-Alias grep "grep --color"
    function du1 { sudo du -h -d1 }

    if ($IsMacOS) {
        function toggle-hidden-file { defaults write com.apple.Finder AppleShowAllFiles }
    }
}
else {
    function grep { Select-String @args }
    function du1 {
        Get-ChildItem -Force | Where-Object { $_ -is [System.IO.DirectoryInfo] } |
        ForEach-Object {
            $size = (Get-ChildItem $_.FullName -Recurse -Force |
                Measure-Object -Property Length -Sum).Sum / 1MB
            [PSCustomObject]@{
                Directory  = $_.Name
                "Size(MB)" = [math]::Round($size, 2)
            }
        } | Format-Table -AutoSize
    }
}

# --- ls aliases ---
function l { Get-ChildItem -Force | Format-List }
function l. { Get-ChildItem -Force -Directory }
Set-Alias la "Get-ChildItem -Force"
function ll { Get-ChildItem -Force | Format-Table Mode, LastWriteTime, Length, Name }
function lh { Get-ChildItem -Force | Format-Table Name, Length, LastWriteTime }

# --- history aliases ---
Set-Alias hi Get-History
function hig {
    param([string]$pattern)
    if ([string]::IsNullOrEmpty($pattern)) {
        Get-History
    }
    else {
        Get-History | Where-Object { $_.CommandLine -match $pattern }
    }
}

# --- chown/chmod ---
function steal {
    Write-Host "No direct chown equivalent on Windows. Use icacls or Set-Acl instead."
}
function 755 {
    Write-Host "No direct chmod equivalent on Windows. Use icacls or Set-Acl instead."
}

# --- kill aliases ---
function ka9 {
    param([Parameter(Mandatory = $true)][string]$processName)
    Stop-Process -Name $processName -Force -ErrorAction SilentlyContinue
}
function k9 {
    param([Parameter(Mandatory = $true)][int]$processId)
    Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
}

# --- rm aliases ---
function rm-rf { Remove-Item -Recurse -Force $args }
function rm-tags { Remove-Item -Force cscope.* ncscope.* tags -ErrorAction SilentlyContinue }

# --- rc aliases ---
function so {
    . $env:PROFILE_PATH
    Write-Host "Profile reloaded."
}
function path { $env:PATH -split [System.IO.Path]::PathSeparator }
function path.lib {
    if ($env:LD_LIBRARY_PATH) {
        $env:LD_LIBRARY_PATH -split [System.IO.Path]::PathSeparator
    }
    else {
        Write-Host "LD_LIBRARY_PATH is not set."
    }
}
function shrc { code $env:PROFILE_PATH }
function vimrc { code $env:USERPROFILE\.vimrc }
function gvimrc { code $env:USERPROFILE\.gvimrc }
function nvimrc { code $env:USERPROFILE\.config\nvim\init.lua }
function tmuxrc { code $env:USERPROFILE\.tmux.conf }

# --- public ip ---
function public-ip {
    try {
        Invoke-RestMethod -Uri "https://ipinfo.io/ip" -TimeoutSec 5
    }
    catch {
        Write-Error "Failed to retrieve public IP: $_"
    }
}

# --- python aliases ---
Set-Alias py python
Set-Alias py3 python3

# --- venv aliases (already provided) ---
function Create-PythonVenv {
    param([string]$VenvName = "venv")
    try {
        python -m venv $VenvName
        Write-Host "Virtual environment '$VenvName' created successfully."
    }
    catch {
        Write-Error "Failed to create virtual environment: $_"
    }
}
Set-Alias venv.create Create-PythonVenv

function Activate-PythonVenv {
    param([string]$VenvName = "venv")
    $activatePath = Join-Path $VenvName "Scripts\Activate.ps1"
    if (Test-Path $activatePath) {
        & $activatePath
        Write-Host "Virtual environment '$VenvName' activated."
    }
    else {
        Write-Error "Virtual environment '$VenvName' not found. Please create it first using venv.create."
    }
}
Set-Alias venv.activate Activate-PythonVenv

# --- tmux aliases (no direct Windows equivalent) ---
Set-Alias t tmux
Set-Alias tl "tmux ls"
function tn {
    param([string]$name)
    if (-not $name) { $name = Split-Path -Leaf (Get-Location) }
    if (Get-Command tmux -ErrorAction SilentlyContinue) {
        tmux new -s $name
    }
    else {
        Write-Error "tmux is not installed or not in PATH"
    }
}
Set-Alias ta "tmux attach"
Set-Alias tat "tmux attach -t"

# --- apt aliases (use winget or choco on Windows) ---
Set-Alias sau "winget upgrade"
Set-Alias sai "winget install"
Set-Alias sas "winget search"
Set-Alias saug "winget upgrade --all"
Set-Alias sadu "winget upgrade --all"
Set-Alias sarm "winget uninstall"

# --- ufw aliases (no direct Windows equivalent) ---
function sus { Write-Host "No direct ufw equivalent on Windows. Consider using Windows Firewall." }
function sen { Write-Host "No direct ufw equivalent on Windows. Consider using Windows Firewall." }
function srm { Write-Host "No direct ufw equivalent on Windows. Consider using Windows Firewall." }

# --- VBoxManage ---
Set-Alias vbm VBoxManage

# --- grep2 ---
function grep2 {
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$pattern,

        [Parameter(Position = 1, Mandatory = $true)]
        [string]$file
    )

    if (Test-Path $file) {
        Get-Content $file | Select-String $pattern | Where-Object { $_ -notmatch "grep" } | Select-String $pattern
    }
    else {
        Write-Error "File not found: $file"
    }
}

# --- xopen ---
function xopen {
    param([string]$path = ".")
    if (Test-Path $path) {
        Invoke-Item $path
    }
    else {
        Write-Error "Path not found: $path"
    }
}

# --- td (tmux detached) ---
function td {
    param(
        [string]$name,
        [string]$cmd
    )
    if (-not $name) { $name = (Get-Location).Path.Split('\')[-1] }

    if (Get-Command tmux -ErrorAction SilentlyContinue) {
        if ($cmd) {
            tmux new -s $name -d $cmd
        }
        else {
            tmux new -s $name -d
        }
    }
    else {
        Write-Host "No direct tmux equivalent on Windows. Would run: tmux new $name -d $cmd"
    }
}

function touch {
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string[]]$Path
    )

    foreach ($file in $Path) {
        if (Test-Path -Path $file) {
            # File exists, update its timestamp
            (Get-Item $file).LastWriteTime = Get-Date
        }
        else {
            # File doesn't exist, create a new empty file
            New-Item -ItemType File -Path $file | Out-Null
        }
    }
}

# --- docker aliases ---
function docker.ps { docker ps --format 'table {{.ID}}\t{{.Names}}' $args }

# --- claude aliases ---
function claude.agents { claude agents --cwd . $args }

# --- End of Aliases ---
