# Unified Repository Creation Script
# Prompts for platform choice (GitHub or Azure DevOps)

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$RepositoryName,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("github", "azure")]
    [string]$Platform,
    
    [Parameter(ValueFromRemainingArguments = $true)]
    $RemainingArguments
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Prompt for platform if not provided
if (-not $Platform) {
    Write-Host "Choose your platform:" -ForegroundColor Cyan
    Write-Host "1) GitHub"
    Write-Host "2) Azure DevOps"
    Write-Host ""
    
    $choice = Read-Host "Enter your choice (1 or 2)"
    
    switch ($choice) {
        "1" { $Platform = "github" }
        "2" { $Platform = "azure" }
        default {
            Write-Host "Invalid choice. Please run again and select 1 or 2." -ForegroundColor Yellow
            exit 1
        }
    }
}

# Execute the appropriate platform script
Write-Host "Creating repository on $Platform..." -ForegroundColor Green

$scriptPath = if ($Platform -eq "github") {
    Join-Path $PSScriptRoot "github\powershell\New-Repo.ps1"
} else {
    Join-Path $PSScriptRoot "azure\powershell\New-Repo.ps1"
}

# Build argument list
$argList = @($RepositoryName)
if ($RemainingArguments) {
    $argList += $RemainingArguments
}

# Execute the script
& $scriptPath @argList