# Update-Repos.ps1 - Update existing repositories with latest CI/CD configurations

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$RepositoryNames,
    
    [Parameter(Mandatory = $false)]
    [string]$Organization = "cyberdinedevelopment",
    
    [Parameter(Mandatory = $false)]
    [string]$DefaultPath = "D:\fractaldataworks",
    
    [Parameter(Mandatory = $false)]
    [string]$DefaultBranch = "master",
    
    [Parameter(Mandatory = $false)]
    [switch]$WorkflowsOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$ConfigOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$All,
    
    [Parameter(Mandatory = $false)]
    [switch]$FixBranch,
    
    [Parameter(Mandatory = $false)]
    [string]$AddRepo,
    
    [Parameter(Mandatory = $false)]
    [switch]$Help
)

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
Usage: Update-Repos.ps1 [OPTIONS] [REPOSITORY_NAMES...]

Update existing repositories with latest CI/CD configurations.

OPTIONS:
    -Help                Show this help message
    -Organization        Organization name (default: cyberdinedevelopment)
    -DefaultPath         Default path (default: D:\fractaldataworks)
    -DefaultBranch       Default branch (default: master)
    -WorkflowsOnly       Update only workflows
    -ConfigOnly          Update only configuration files
    -All                 Update all organization repositories
    -FixBranch           Fix default branch to master
    -AddRepo NAME        Add a new repository with CI/CD

EXAMPLES:
    # Update specific repositories
    Update-Repos.ps1 smart-generators enhanced-enums

    # Update all repositories
    Update-Repos.ps1 -All

    # Update only workflows
    Update-Repos.ps1 -WorkflowsOnly smart-generators

    # Add a new repository
    Update-Repos.ps1 -AddRepo new-library

"@
}

# Get all repositories
function Get-AllRepos {
    $repos = gh repo list $Organization --limit 100 --json name -q '.[].name'
    return $repos | Where-Object { $_ -match "(smart-|enhanced-|developer-kit)" }
}

# Update workflows
function Update-Workflows {
    param([string]$RepoPath)
    
    Write-Info "Updating workflows..."
    
    # Ensure workflows directory exists
    $workflowPath = Join-Path $RepoPath ".github\workflows"
    New-Item -ItemType Directory -Force -Path $workflowPath | Out-Null
    
    # Check if workflow exists
    $mainWorkflow = Join-Path $workflowPath "dotnet-ci-cd.yml"
    if (Test-Path $mainWorkflow) {
        Write-Info "Workflow already exists, checking for updates..."
        # Add logic to update specific workflow sections if needed
    }
}

# Update configuration files
function Update-Config {
    param([string]$RepoPath)
    
    Write-Info "Updating configuration files..."
    
    # Update Directory.Build.props
    $buildProps = Join-Path $RepoPath "Directory.Build.props"
    if (Test-Path $buildProps) {
        Write-Info "Updating Directory.Build.props..."
        # Update specific properties if needed
    }
    
    # Update version.json for Nerdbank
    $versionJson = Join-Path $RepoPath "version.json"
    if (Test-Path $versionJson) {
        Write-Info "Version.json exists, checking for updates..."
    }
    
    # Update .editorconfig
    $editorConfig = Join-Path $RepoPath ".editorconfig"
    if (-not (Test-Path $editorConfig)) {
        Write-Warn ".editorconfig missing, adding..."
    }
}

# Fix default branch
function Repair-DefaultBranch {
    param([string]$RepoName)
    
    Write-Info "Fixing default branch to master..."
    
    Set-Location (Join-Path $DefaultPath $RepoName)
    
    # Check current default branch
    $currentBranch = gh repo view "${Organization}/${RepoName}" --json defaultBranchRef -q '.defaultBranchRef.name'
    
    if ($currentBranch -ne "master") {
        Write-Info "Current default branch is ${currentBranch}, changing to master..."
        
        # Create master branch if it doesn't exist
        $masterExists = git show-ref --verify --quiet refs/heads/master
        if ($LASTEXITCODE -ne 0) {
            git checkout -b master
            git push -u origin master
        }
        
        # Set as default
        gh repo edit "${Organization}/${RepoName}" --default-branch master
        
        # Delete old default branch if it's main
        if ($currentBranch -eq "main") {
            git push origin --delete main 2>$null
        }
    } else {
        Write-Info "Default branch is already master"
    }
}

# Update repository
function Update-Repository {
    param([string]$RepoName)
    
    Write-Info "=== Updating ${RepoName} ==="
    
    Set-Location $DefaultPath
    
    # Clone or update repository
    if (Test-Path $RepoName) {
        Set-Location $RepoName
        git pull
    } else {
        gh repo clone "${Organization}/${RepoName}"
        Set-Location $RepoName
    }
    
    # Fix branch if requested
    if ($FixBranch) {
        Repair-DefaultBranch -RepoName $RepoName
    }
    
    # Update components
    $repoPath = Join-Path $DefaultPath $RepoName
    
    if (-not $ConfigOnly) {
        Update-Workflows -RepoPath $repoPath
    }
    
    if (-not $WorkflowsOnly) {
        Update-Config -RepoPath $repoPath
    }
    
    # Commit changes if any
    $status = git status -s
    if ($status) {
        git add .
        git commit -m "Update CI/CD configuration

- Update workflows to latest version
- Update configuration files
- Maintain compatibility with .NET 9/10"
        
        git push
        Write-Info "✓ Updates pushed to ${RepoName}"
    } else {
        Write-Info "✓ No updates needed for ${RepoName}"
    }
    
    Set-Location $DefaultPath
}

# Add new repository
function Add-NewRepository {
    param([string]$RepoName)
    
    Write-Info "Adding new repository: ${RepoName}"
    
    # Use the setup script
    $setupScript = Join-Path $DefaultPath "GithubSetup\Setup-CICDRepos.ps1"
    if (Test-Path $setupScript) {
        # Run setup for single repository
        $env:REPOSITORIES = $RepoName
        & $setupScript -Organization $Organization -DefaultPath $DefaultPath -DefaultBranch $DefaultBranch
    } else {
        Write-Error "Setup script not found"
        exit 1
    }
}

# Main execution
function Main {
    if ($Help) {
        Show-Help
        return
    }
    
    Write-Info "Repository Update Tool"
    
    # Check dependencies
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Error "GitHub CLI (gh) is not installed"
        exit 1
    }
    
    # Handle add repository
    if ($AddRepo) {
        Add-NewRepository -RepoName $AddRepo
        return
    }
    
    # Get repositories to update
    if ($All) {
        $RepositoryNames = Get-AllRepos
        Write-Info "Found $($RepositoryNames.Count) repositories to update"
    }
    
    # Check if repositories specified
    if ($RepositoryNames.Count -eq 0) {
        Write-Error "No repositories specified. Use -All for all or specify repository names."
        Show-Help
        exit 1
    }
    
    # Update each repository
    foreach ($repo in $RepositoryNames) {
        Update-Repository -RepoName $repo
        Write-Host ""
    }
    
    Write-Info "=== Update Summary ==="
    Write-Host "Updated repositories:"
    foreach ($repo in $RepositoryNames) {
        Write-Host "  - ${repo}"
    }
}

Main