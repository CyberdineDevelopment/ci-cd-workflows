# Setup-All.ps1 - Complete CI/CD setup for CyberDine Development with configuration management

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "..\..\..\config.json",
    
    [Parameter(Mandatory = $false)]
    [switch]$ReconfigureAll,
    
    [Parameter(Mandatory = $false)]
    [switch]$Help
)

# Configuration structure
$DefaultConfig = @{
    GitHubOrganization = "cyberdinedevelopment"
    CompanyName = "FractalDataWorks"
    DefaultPath = "$env:USERPROFILE\source\repos"
    DefaultBranch = "master"
    RepositoryVisibility = "private"  # private or public
    DefaultLicense = "Apache-2.0"  # Apache-2.0 or MIT
    ScriptPath = ""
    LastUpdated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# Logging functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] ${Message}" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] ${Message}" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] ${Message}" -ForegroundColor Red
}

# Show help
function Show-Help {
    Write-Host @"
Setup-All.ps1 - Complete CI/CD setup for CyberDine Development

USAGE:
    Setup-All.ps1 [OPTIONS]

OPTIONS:
    -ConfigPath PATH        Path to configuration file (default: .\config.json)
    -ReconfigureAll         Force reconfiguration of all settings
    -Help                   Show this help message

DESCRIPTION:
    This script orchestrates the complete CI/CD setup process:
    1. Creates/loads configuration settings
    2. Creates the ci-cd-workflows repository
    3. Optionally creates project repositories
    4. Provides clear next steps

CONFIGURATION:
    The script creates a configuration file to store settings:
    - Organization name
    - Default path for repositories
    - Repository visibility (private/public)
    - Default branch name

EXAMPLES:
    # First time setup (will prompt for configuration)
    Setup-All.ps1
    
    # Force reconfiguration
    Setup-All.ps1 -ReconfigureAll
    
    # Use custom config location
    Setup-All.ps1 -ConfigPath "..\cicd-config.json"

"@
}

# Load or create configuration
function Get-CICDConfiguration {
    param([string]$ConfigFilePath)
    
    if ($ReconfigureAll -or -not (Test-Path $ConfigFilePath)) {
        Write-Info "Setting up CI/CD configuration"
        
        # Ensure config directory exists
        $configDir = Split-Path $ConfigFilePath -Parent
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        
        # Interactive configuration
        $config = $DefaultConfig.Clone()
        
        Write-Host ""
        Write-Host "=== CI/CD Configuration Setup ===" -ForegroundColor Cyan
        Write-Host ""
        
        # GitHub Organization
        $orgInput = Read-Host "GitHub Organization name (default: $($config.GitHubOrganization))"
        if ($orgInput) { $config.GitHubOrganization = $orgInput }
        
        # Company Name
        $companyInput = Read-Host "Company name (default: $($config.CompanyName))"
        if ($companyInput) { $config.CompanyName = $companyInput }
        
        # Default path
        $windowsDefault = "$env:USERPROFILE\source\repos"
        $pathInput = Read-Host "Default path for repositories (default: $windowsDefault)"
        if ($pathInput) { $config.DefaultPath = $pathInput } else { $config.DefaultPath = $windowsDefault }
        
        # Repository visibility
        Write-Host ""
        Write-Host "Repository visibility options:"
        Write-Host "  1) Private (recommended for internal projects)"
        Write-Host "  2) Public (for open source projects)"
        $visChoice = Read-Host "Select repository visibility (1-2, default: 1)"
        switch ($visChoice) {
            "2" { $config.RepositoryVisibility = "public" }
            default { $config.RepositoryVisibility = "private" }
        }
        
        # Default branch
        $branchInput = Read-Host "Default branch name (default: $($config.DefaultBranch))"
        if ($branchInput) { $config.DefaultBranch = $branchInput }
        
        # Default license
        Write-Host ""
        Write-Host "Default license options:"
        Write-Host "  1) Apache-2.0 (recommended for business)"
        Write-Host "  2) MIT (simple permissive)"
        $licenseChoice = Read-Host "Select default license (1-2, default: 1)"
        switch ($licenseChoice) {
            "2" { $config.DefaultLicense = "MIT" }
            default { $config.DefaultLicense = "Apache-2.0" }
        }
        
        # Set script path
        $config.ScriptPath = Split-Path $PSScriptRoot -Parent
        $config.LastUpdated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        
        # Save configuration
        $config | ConvertTo-Json -Depth 3 | Out-File -FilePath $ConfigFilePath -Encoding UTF8
        Write-Info "Configuration saved to: $ConfigFilePath"
        
        return $config
    }
    else {
        Write-Info "Loading existing configuration from: $ConfigFilePath"
        $config = Get-Content $ConfigFilePath -Raw | ConvertFrom-Json
        
        # Convert to hashtable for easier manipulation
        $configHash = @{}
        $config.PSObject.Properties | ForEach-Object { $configHash[$_.Name] = $_.Value }
        
        return $configHash
    }
}

# Create ci-cd-workflows repository
function Invoke-CreateCICDWorkflows {
    param([hashtable]$Config)
    
    Write-Info "Step 1: Creating ci-cd-workflows repository..."
    
    $createScript = Join-Path $PSScriptRoot "Create-CICDWorkflowsRepo.ps1"
    if (Test-Path $createScript) {
        & $createScript -Organization $Config.GitHubOrganization -DefaultPath $Config.DefaultPath -DefaultBranch $Config.DefaultBranch
    }
    else {
        Write-Error "Create-CICDWorkflowsRepo.ps1 not found at: $createScript"
        return $false
    }
    
    return $true
}

# Create project repositories
function Invoke-CreateRepositories {
    param([hashtable]$Config)
    
    Write-Info "Creating all project repositories..."
    
    $setupScript = Join-Path $PSScriptRoot "Setup-CICDRepos.ps1"
    if (Test-Path $setupScript) {
        $visibility = if ($Config.RepositoryVisibility -eq "public") { "public" } else { "private" }
        
        & $setupScript `
            -Organization $Config.GitHubOrganization `
            -DefaultPath $Config.DefaultPath `
            -DefaultBranch $Config.DefaultBranch `
            -RepositoryVisibility $visibility
    }
    else {
        Write-Error "Setup-CICDRepos.ps1 not found at: $setupScript"
        return $false
    }
    
    return $true
}

# Create test repository
function Invoke-CreateTestRepository {
    param([hashtable]$Config)
    
    Write-Info "Creating test repository..."
    
    Set-Location $Config.DefaultPath
    
    $repoVisibility = if ($Config.RepositoryVisibility -eq "public") { "--public" } else { "--private" }
    
    $createCommand = "gh repo create `"$($Config.GitHubOrganization)/test-cicd-pipeline`" " +
                    "$repoVisibility " +
                    "--description `"Test repository for CI/CD pipeline validation`" " +
                    "--gitignore `"VisualStudio`" " +
                    "--license `"MIT`" " +
                    "--confirm"
    
    try {
        Invoke-Expression $createCommand
        Write-Info "✓ Test repository created successfully"
    }
    catch {
        Write-Warn "Test repository may already exist"
    }
}

# Show completion summary
function Show-CompletionSummary {
    param([hashtable]$Config)
    
    Write-Host ""
    Write-Info "=== Setup Complete ==="
    Write-Host ""
    Write-Host "CI/CD Workflows Repository: https://github.com/$($Config.GitHubOrganization)/ci-cd-workflows" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Yellow
    Write-Host "  Organization: $($Config.GitHubOrganization)"
    Write-Host "  Default Path: $($Config.DefaultPath)"
    Write-Host "  Repository Visibility: $($Config.RepositoryVisibility)"
    Write-Host "  Default Branch: $($Config.DefaultBranch)"
    Write-Host ""
    Write-Host "Available scripts in ci-cd-workflows/scripts/:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  PowerShell:" -ForegroundColor Cyan
    Write-Host "    - Setup-CICDRepos.ps1      # Create new repositories"
    Write-Host "    - Update-Repos.ps1         # Update existing repositories"
    Write-Host "    - Add-AzureKeyVault.ps1    # Add Azure Key Vault integration"
    Write-Host "    - Setup-All.ps1            # This script (with config management)"
    Write-Host ""
    Write-Host "  Bash:" -ForegroundColor Cyan
    Write-Host "    - setup-cicd-repos.sh      # Create new repositories"
    Write-Host "    - update-repos.sh          # Update existing repositories"
    Write-Host "    - add-azure-keyvault.sh    # Add Azure Key Vault integration"
    Write-Host "    - setup-all.sh             # Master setup script"
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Clone the ci-cd-workflows repository"
    Write-Host "2. Use scripts from the scripts/ directory"
    Write-Host "3. Add your library code to the /src folder of each repository"
    Write-Host "4. Update NUGET_API_KEY secret: gh secret set NUGET_API_KEY --org $($Config.GitHubOrganization)"
    Write-Host "5. Configure GitHub teams (developers, devops, security)"
    Write-Host ""
    Write-Host "Configuration file: $ConfigPath" -ForegroundColor Green
}

# Main execution
function Main {
    if ($Help) {
        Show-Help
        return
    }
    
    Write-Info "Complete CI/CD Setup for CyberDine Development"
    Write-Host ""
    
    # Check dependencies
    $deps = @("gh", "git", "dotnet")
    foreach ($dep in $deps) {
        if (-not (Get-Command $dep -ErrorAction SilentlyContinue)) {
            Write-Error "${dep} is not installed"
            exit 1
        }
    }
    
    # Check GitHub authentication
    try {
        gh auth status 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Not authenticated with GitHub. Run 'gh auth login' first."
            exit 1
        }
    }
    catch {
        Write-Error "GitHub CLI error. Ensure gh is properly installed."
        exit 1
    }
    
    # Load or create configuration
    $config = Get-CICDConfiguration -ConfigFilePath $ConfigPath
    
    Write-Host ""
    Write-Info "Using configuration:"
    Write-Host "  GitHub Organization: $($config.GitHubOrganization)"
    Write-Host "  Company Name: $($config.CompanyName)"
    Write-Host "  Default Path: $($config.DefaultPath)"
    Write-Host "  Repository Visibility: $($config.RepositoryVisibility)"
    Write-Host "  Default Branch: $($config.DefaultBranch)"
    Write-Host "  Default License: $($config.DefaultLicense)"
    Write-Host ""
    
    # Ensure default path exists
    if (-not (Test-Path $config.DefaultPath)) {
        New-Item -ItemType Directory -Path $config.DefaultPath -Force | Out-Null
        Write-Info "Created default path: $($config.DefaultPath)"
    }
    
    # Step 1: Create ci-cd-workflows repository
    if (-not (Invoke-CreateCICDWorkflows -Config $config)) {
        Write-Error "Failed to create ci-cd-workflows repository"
        exit 1
    }
    
    # Step 2: Repository creation options
    Write-Host ""
    Write-Info "Step 2: Repository setup options"
    Write-Host "1) Create all 5 repositories (smart-generators, enhanced-enums, etc.)"
    Write-Host "2) Create test repository only"
    Write-Host "3) Skip repository creation"
    
    do {
        $choice = Read-Host "Select option (1-3)"
    } while ($choice -notin @("1", "2", "3"))
    
    switch ($choice) {
        "1" {
            if (-not (Invoke-CreateRepositories -Config $config)) {
                Write-Error "Failed to create repositories"
                exit 1
            }
        }
        "2" {
            Invoke-CreateTestRepository -Config $config
        }
        "3" {
            Write-Info "Skipping repository creation"
        }
    }
    
    # Show completion summary
    Show-CompletionSummary -Config $config
}

# Run main function
Main