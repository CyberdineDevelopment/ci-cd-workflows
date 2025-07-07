# Create-CICDWorkflowsRepo.ps1 - Create the ci-cd-workflows repository

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Organization = "cyberdinedevelopment",
    
    [Parameter(Mandatory = $false)]
    [string]$DefaultPath = "D:\fractaldataworks",
    
    [Parameter(Mandatory = $false)]
    [string]$DefaultBranch = "master",
    
    [Parameter(Mandatory = $false)]
    [switch]$CreateTestRepo
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

# Create ci-cd-workflows repository
function New-CICDWorkflowsRepo {
    Write-Info "Creating ci-cd-workflows repository..."
    
    Set-Location $DefaultPath
    
    # Create repository
    try {
        gh repo create "${Organization}/ci-cd-workflows" `
            --public `
            --description "CI/CD workflow templates and scripts for CyberDine Development" `
            --gitignore "VisualStudio" `
            --license "MIT" `
            --confirm
            
        # Clone the repository
        gh repo clone "${Organization}/ci-cd-workflows"
    } catch {
        Write-Warn "Repository may already exist"
        gh repo clone "${Organization}/ci-cd-workflows"
    }
    
    # Change to repo directory
    Set-Location (Join-Path $DefaultPath "ci-cd-workflows")
    
    # Change default branch if needed
    if ($DefaultBranch -ne "main") {
        git checkout -b $DefaultBranch 2>$null
        if ($LASTEXITCODE -ne 0) {
            git checkout $DefaultBranch
        }
        git push -u origin $DefaultBranch 2>$null
        gh repo edit "${Organization}/ci-cd-workflows" --default-branch $DefaultBranch
        git push origin --delete main 2>$null
    }
    
    # Configure repository
    gh repo edit "${Organization}/ci-cd-workflows" `
        --enable-issues `
        --enable-wiki `
        --enable-discussions `
        --delete-branch-on-merge `
        --add-topic "cicd,github-actions,devops"
}

# Create repository structure
function New-RepoStructure {
    Write-Info "Creating repository structure..."
    
    # Create directories
    New-Item -ItemType Directory -Force -Path "scripts\bash" | Out-Null
    New-Item -ItemType Directory -Force -Path "scripts\powershell" | Out-Null
    New-Item -ItemType Directory -Force -Path "workflows" | Out-Null
    New-Item -ItemType Directory -Force -Path "docs" | Out-Null
    
    # Copy scripts from GithubSetup
    $githubSetupPath = Join-Path $DefaultPath "GithubSetup"
    
    # Copy bash scripts
    Copy-Item (Join-Path $githubSetupPath "setup-cicd-repos.sh") "scripts\bash\"
    Copy-Item (Join-Path $githubSetupPath "add-azure-keyvault.sh") "scripts\bash\"
    Copy-Item (Join-Path $githubSetupPath "create-cicd-workflows-repo.sh") "scripts\bash\"
    
    # Copy PowerShell scripts
    Copy-Item (Join-Path $githubSetupPath "Setup-CICDRepos.ps1") "scripts\powershell\"
    Copy-Item (Join-Path $githubSetupPath "Create-CICDWorkflowsRepo.ps1") "scripts\powershell\"
    
    # Create README
    @'
# CI/CD Workflows and Scripts

This repository contains CI/CD workflow templates and setup scripts for CyberDine Development projects.

## Repository Structure

```
├── scripts/
│   ├── bash/              # Bash scripts for Linux/macOS/WSL
│   └── powershell/        # PowerShell scripts for Windows
├── workflows/             # Reusable GitHub Actions workflows
└── docs/                  # Documentation
```

## Quick Start

### Create New Repositories

**Bash (Linux/macOS/WSL):**
```bash
cd scripts/bash
./setup-cicd-repos.sh
```

**PowerShell (Windows):**
```powershell
cd scripts\powershell
.\Setup-CICDRepos.ps1
```

### Repository Templates Created

The scripts create the following repositories with full CI/CD:
- `smart-generators` - Smart code generators for .NET
- `enhanced-enums` - Enhanced enum functionality
- `smart-switches` - Intelligent switch expressions
- `smart-delegates` - Smart delegate utilities
- `developer-kit` - Comprehensive developer toolkit

## Features

- ✅ GitHub Actions workflows for CI/CD
- ✅ Nerdbank.GitVersioning with SemVer 2.0
- ✅ Security scanning (CodeQL, MSDO, Trivy)
- ✅ SBOM generation
- ✅ Branch protection rules
- ✅ Environment-based deployments
- ✅ GitHub Packages integration
- ✅ Automated dependency updates

## Configuration

All repositories are configured with:
- Default branch: `master`
- .NET 9/10 support
- Private visibility (can be changed)
- MIT license
- Full security scanning

## Versioning

Uses Nerdbank.GitVersioning for deterministic versioning:
- Format: `MAJOR.MINOR.PATCH[-PRERELEASE]+[BUILDMETADATA]`
- Example: `1.0.42-alpha+g1a2b3c4`

## Security

- Weekly vulnerability scanning
- Dependabot for dependency updates
- CodeQL analysis on every push
- SBOM generation for releases

## License

MIT
'@ | Out-File -FilePath "README.md" -Encoding utf8

    # Create workflow documentation
    @'
# GitHub Actions Workflows

## Main CI/CD Pipeline

The main workflow (`dotnet-ci-cd.yml`) includes:

1. **Build and Test**
   - Multi-version .NET support (9.0.x, 10.0.x)
   - Code coverage reporting
   - Artifact uploads

2. **Security Scanning**
   - CodeQL analysis
   - Microsoft Security DevOps
   - Vulnerability scanning

3. **Package Publishing**
   - GitHub Packages
   - NuGet.org (on release tags)
   - Environment protection

## Security Workflow

Weekly security scanning (`security.yml`):
- Vulnerable package detection
- Trivy security scanning
- SBOM generation
- Automatic issue creation

## Workflow Permissions

All workflows use least-privilege permissions:
- `contents: read` (default)
- `packages: write` (only for publishing)
- `security-events: write` (only for security scanning)
'@ | Out-File -FilePath "docs\workflows.md" -Encoding utf8

    # Create usage documentation
    @'
# Usage Guide

## Prerequisites

1. Install GitHub CLI: https://cli.github.com/
2. Install .NET SDK 9.0+: https://dotnet.microsoft.com/
3. Authenticate: `gh auth login`

## Creating New Repositories

### Basic Usage

```bash
# From the scripts directory
./setup-cicd-repos.sh
```

### Custom Organization

```powershell
.\Setup-CICDRepos.ps1 -Organization "my-org" -DefaultPath "C:\Projects"
```

## Post-Setup Tasks

1. **Add NuGet API Key**
   ```bash
   gh secret set NUGET_API_KEY --org cyberdinedevelopment
   ```

2. **Create Teams**
   - developers
   - devops
   - security

3. **Add Library Code**
   - Place in `/src` folder
   - Tests in `/tests` folder
   - Documentation in `/docs`

## Versioning Commands

```bash
# Check current version
nbgv get-version

# Prepare release
nbgv prepare-release

# Tag release
nbgv tag
```
'@ | Out-File -FilePath "docs\usage.md" -Encoding utf8

    # Commit all files
    git add .
    git commit -m "Add CI/CD workflow scripts and documentation

- Add repository setup scripts (bash and PowerShell)
- Add comprehensive documentation
- Configure for CyberDine Development organization
- Support for .NET 9/10 with Nerdbank.GitVersioning"
    
    git push -u origin $DefaultBranch
}

# Create test repository
function New-TestRepo {
    Write-Info "Creating test-cicd-pipeline repository..."
    
    Set-Location $DefaultPath
    
    # Create test repository
    try {
        gh repo create "${Organization}/test-cicd-pipeline" `
            --private `
            --description "Test repository for CI/CD pipeline validation" `
            --gitignore "VisualStudio" `
            --license "MIT" `
            --confirm
            
        # Clone the repository
        gh repo clone "${Organization}/test-cicd-pipeline"
    } catch {
        Write-Warn "Test repository may already exist"
        gh repo clone "${Organization}/test-cicd-pipeline"
    }
    
    # Setup the test repository using our scripts
    $scriptPath = Join-Path $DefaultPath "GithubSetup\Setup-CICDRepos.ps1"
    & $scriptPath -Organization $Organization -DefaultPath $DefaultPath -DefaultBranch $DefaultBranch
}

# Main execution
function Main {
    Write-Info "Setting up CI/CD workflows repository"
    
    # Create ci-cd-workflows repository
    New-CICDWorkflowsRepo
    New-RepoStructure
    
    Write-Info "✓ CI/CD workflows repository created"
    Write-Host ""
    
    # Ask about test repository
    if ($CreateTestRepo -or (Read-Host "Create test-cicd-pipeline repository for testing? (y/n)") -eq 'y') {
        New-TestRepo
        Write-Info "✓ Test repository created"
    }
    
    Write-Host ""
    Write-Info "Setup complete!"
    Write-Host "CI/CD Workflows: https://github.com/${Organization}/ci-cd-workflows"
    if ($CreateTestRepo) {
        Write-Host "Test Repository: https://github.com/${Organization}/test-cicd-pipeline"
    }
}

Main