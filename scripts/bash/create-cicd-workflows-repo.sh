#!/bin/bash
# create-cicd-workflows-repo.sh - Create the ci-cd-workflows repository

set -e

# Configuration
ORG_NAME="cyberdinedevelopment"
DEFAULT_PATH="/mnt/d/fractaldataworks"
DEFAULT_BRANCH="master"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Create ci-cd-workflows repository
create_cicd_workflows_repo() {
    log_info "Creating ci-cd-workflows repository..."
    
    cd "$DEFAULT_PATH"
    
    # Create repository
    gh repo create "$ORG_NAME/ci-cd-workflows" \
        --public \
        --description "CI/CD workflow templates and scripts for CyberDine Development" \
        --gitignore "VisualStudio" \
        --license "MIT" \
        --confirm || {
            log_warn "Repository may already exist"
            gh repo clone "$ORG_NAME/ci-cd-workflows"
        }
    
    # Clone if not already cloned
    if [ ! -d "ci-cd-workflows" ]; then
        gh repo clone "$ORG_NAME/ci-cd-workflows"
    fi
    
    cd ci-cd-workflows
    
    # Change default branch if needed
    if [[ "$DEFAULT_BRANCH" != "main" ]]; then
        git checkout -b "$DEFAULT_BRANCH" 2>/dev/null || git checkout "$DEFAULT_BRANCH"
        git push -u origin "$DEFAULT_BRANCH" 2>/dev/null || true
        gh repo edit "$ORG_NAME/ci-cd-workflows" --default-branch "$DEFAULT_BRANCH"
        git push origin --delete main 2>/dev/null || true
    fi
    
    # Configure repository
    gh repo edit "$ORG_NAME/ci-cd-workflows" \
        --enable-issues \
        --enable-wiki \
        --enable-discussions \
        --delete-branch-on-merge \
        --add-topic "cicd,github-actions,devops"
}

# Create repository structure
create_repo_structure() {
    log_info "Creating repository structure..."
    
    # Create directories
    mkdir -p scripts/bash
    mkdir -p scripts/powershell
    mkdir -p workflows
    mkdir -p docs
    
    # Copy scripts from GithubSetup
    cp "$DEFAULT_PATH/GithubSetup/setup-cicd-repos.sh" scripts/bash/
    cp "$DEFAULT_PATH/GithubSetup/update-repos.sh" scripts/bash/
    cp "$DEFAULT_PATH/GithubSetup/add-azure-keyvault.sh" scripts/bash/
    cp "$DEFAULT_PATH/GithubSetup/create-cicd-workflows-repo.sh" scripts/bash/
    
    cp "$DEFAULT_PATH/GithubSetup/Setup-CICDRepos.ps1" scripts/powershell/
    cp "$DEFAULT_PATH/GithubSetup/Update-Repos.ps1" scripts/powershell/
    cp "$DEFAULT_PATH/GithubSetup/Add-AzureKeyVault.ps1" scripts/powershell/
    cp "$DEFAULT_PATH/GithubSetup/Create-CICDWorkflowsRepo.ps1" scripts/powershell/
    
    # Create README
    cat > README.md << 'EOF'
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
EOF

    # Create workflow documentation
    cat > docs/workflows.md << 'EOF'
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
EOF

    # Create usage documentation
    cat > docs/usage.md << 'EOF'
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
EOF

    # Commit all files
    git add .
    git commit -m "Add CI/CD workflow scripts and documentation

- Add repository setup scripts (bash and PowerShell)
- Add comprehensive documentation
- Configure for CyberDine Development organization
- Support for .NET 9/10 with Nerdbank.GitVersioning"
    
    git push -u origin "$DEFAULT_BRANCH"
}

# Create test repository
create_test_repo() {
    log_info "Creating test-cicd-pipeline repository..."
    
    cd "$DEFAULT_PATH"
    
    # Create test repository
    gh repo create "$ORG_NAME/test-cicd-pipeline" \
        --private \
        --description "Test repository for CI/CD pipeline validation" \
        --gitignore "VisualStudio" \
        --license "MIT" \
        --confirm || {
            log_warn "Test repository may already exist"
            gh repo clone "$ORG_NAME/test-cicd-pipeline"
        }
    
    # Clone if not already cloned
    if [ ! -d "test-cicd-pipeline" ]; then
        gh repo clone "$ORG_NAME/test-cicd-pipeline"
    fi
    
    cd test-cicd-pipeline
    
    # Change default branch if needed
    if [[ "$DEFAULT_BRANCH" != "main" ]]; then
        git checkout -b "$DEFAULT_BRANCH" 2>/dev/null || git checkout "$DEFAULT_BRANCH"
        git push -u origin "$DEFAULT_BRANCH" 2>/dev/null || true
        gh repo edit "$ORG_NAME/test-cicd-pipeline" --default-branch "$DEFAULT_BRANCH"
        git push origin --delete main 2>/dev/null || true
    fi
    
    # Run the setup script to configure it
    bash "$DEFAULT_PATH/GithubSetup/setup-cicd-repos.sh"
}

# Main execution
main() {
    log_info "Setting up CI/CD workflows repository"
    
    # Create ci-cd-workflows repository
    create_cicd_workflows_repo
    create_repo_structure
    
    log_info "✓ CI/CD workflows repository created"
    echo ""
    
    # Ask about test repository
    read -p "Create test-cicd-pipeline repository for testing? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        create_test_repo
        log_info "✓ Test repository created"
    fi
    
    echo ""
    log_info "Setup complete!"
    echo "CI/CD Workflows: https://github.com/$ORG_NAME/ci-cd-workflows"
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Test Repository: https://github.com/$ORG_NAME/test-cicd-pipeline"
    fi
}

main "$@"