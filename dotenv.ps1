# Define the path to the PowerShell profile
$profilePath = $PROFILE

# Define the lines we want to add
$linesToAdd = @(
    '. $Env:USERPROFILE\.env\inc\git-aliases.ps1',
    '. $Env:USERPROFILE\.env\inc\prompt.ps1',
    '. $Env:USERPROFILE\.env\inc\claude.ps1'
)

function Add-LineIfNotExists {
    param (
        [string]$FilePath,
        [string]$Line
    )

    if (-not (Test-Path $FilePath)) {
        New-Item -Path $FilePath -ItemType File -Force | Out-Null
        Write-Host "Created new profile file: $FilePath"
    }

    $content = Get-Content $FilePath -ErrorAction SilentlyContinue

    if ($content -notcontains $Line) {
        Add-Content -Path $FilePath -Value $Line
        Write-Host "Added line to profile: $Line"
    }
    else {
        Write-Host "Line already exists in profile: $Line"
    }
}

function Patch-Profile {
    Write-Host "Patching PowerShell profile..."
    foreach ($line in $linesToAdd) {
        Add-LineIfNotExists -FilePath $profilePath -Line $line
    }
    Write-Host "Profile patching complete."
}

function Update-Dotenv {
    # Pull the latest dotenv, then add any profile lines introduced since the
    # last patch. Patch-Profile only appends missing lines, so this is safe.
    # Run the pulled script, not this in-memory copy, so new lines are seen.
    Write-Host "Updating $PSScriptRoot ..."
    git -C $PSScriptRoot pull --ff-only
    if ($LASTEXITCODE -ne 0) {
        Write-Host "git pull failed; profile not patched."
        exit 1
    }
    & $PSCommandPath patch
    Write-Host "Updated. Open a new PowerShell window to load the changes."
}

function Print-Usage {
    Write-Host "Usage: .\ManagePowerShellProfile.ps1 [patch]"
    Write-Host "  patch: Patch the PowerShell profile"
    Write-Host "  update: Pull the latest dotenv, then patch the profile"
    Write-Host "  If no argument is provided, patch will be executed by default."
}

# Main script execution
if ($args.Count -eq 0) {
    Patch-Profile
}
else {
    switch ($args[0].ToLower()) {
        "patch" {
            Patch-Profile
        }
        "update" {
            Update-Dotenv
        }
        "-h" {
            Print-Usage
        }
        "--help" {
            Print-Usage
        }
        "--usage" {
            Print-Usage
        }
        default {
            Write-Host "Invalid argument. Use -h or --help for usage information."
        }
    }
}
