# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains CI/CD workflow templates and setup scripts for creating and managing .NET repositories with comprehensive GitHub Actions pipelines. The scripts support both PowerShell (Windows) and Bash (Linux/macOS/WSL) environments.

## Common Commands

### Creating a New Repository
```bash
# Unified script (prompts for platform choice)
cd scripts
./new-repo.sh my-awesome-library

# Platform-specific scripts
# GitHub - Bash (Linux/macOS/WSL)
cd scripts/github/bash
./new-repo.sh my-awesome-library

# GitHub - PowerShell (Windows)  
cd scripts\github\powershell
.\New-Repo.ps1 my-awesome-library

# Azure DevOps - Bash (Linux/macOS/WSL)
cd scripts/azure/bash
./new-repo.sh my-awesome-library

# Azure DevOps - PowerShell (Windows)
cd scripts\azure\powershell
.\New-Repo.ps1 my-awesome-library
```

### Setting Up Multiple Repositories
```bash
# Bash
cd scripts/bash
./setup-all.sh

# PowerShell
cd scripts\powershell
.\Setup-All.ps1
```

### Adding Azure Key Vault Integration
```bash
# Bash
cd scripts/bash
./add-azure-keyvault.sh

# PowerShell
cd scripts\powershell
.\Add-AzureKeyVault.ps1
```

## Architecture and Code Structure

### Script Organization
- **scripts/**: Root scripts directory with unified platform selector
  - **github/bash/**: GitHub setup scripts for Linux/macOS/WSL
  - **github/powershell/**: GitHub setup scripts for Windows PowerShell
  - **azure/bash/**: Azure DevOps setup scripts for Linux/macOS/WSL  
  - **azure/powershell/**: Azure DevOps setup scripts for Windows PowerShell
- **workflows/**: Reusable GitHub Actions workflow templates
- **pipelines/**: Azure DevOps pipeline templates
- **docs/**: Documentation files

### Key Components

1. **Configuration Management**
   - Uses `config.json` (gitignored) for organization settings
   - Supports dual-path configuration (WSLPath for bash, WindowsPath for PowerShell)
   - Auto-prompts for configuration on first run
   - Config structure includes:
     - **GitHub**: GitHubOrganization, CompanyName, WSLPath, WindowsPath, DefaultBranch (always "master"), RepositoryVisibility, DefaultLicense
     - **Azure DevOps**: AzureOrganization, AzureProject, ArtifactFeed (organization-scoped)

2. **Repository Creation Scripts**
   - `new-repo.sh` / `New-Repo.ps1`: Creates single repository with full CI/CD
   - `setup-cicd-repos.sh` / `Setup-CICDRepos.ps1`: Creates multiple predefined repositories
   - All scripts set up: GitHub Actions workflows, Nerdbank.GitVersioning, branch protection, security scanning

3. **GitHub Actions Workflows**
   - `dotnet-ci-cd.yml`: Main CI/CD pipeline
     - Triggers: push to master/develop/feature/*/release/*, tags (v*), PRs, manual dispatch
     - Jobs: build (multi-version .NET 9/10), test with coverage, security scanning (CodeQL, MSDO), package publishing
     - Publishing: GitHub Packages (all branches), NuGet.org (only release tags)
     - Security scanning runs on master, develop, and release branches
     - Includes dependency vulnerability scanning via `dotnet list package --vulnerable`
   - `security.yml`: Weekly security audit (Monday 8 AM)
     - Vulnerable package detection with automatic issue creation
     - Trivy security scanning for CRITICAL/HIGH vulnerabilities
     - SBOM generation using CycloneDX
   - `azure-keyvault.yml`: Reusable workflow for Key Vault secrets
     - Uses OIDC authentication (no passwords)
     - Retrieves secrets: database-url, api-key, storage-connection
     - Requires organization secrets: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID

### Important Implementation Details

**Develop Branch Special Configuration:**
- Test failures are allowed (uses `|| [ "${{ github.ref }}" == "refs/heads/develop" ]`)
- Warnings as errors disabled
- Common analyzer warnings suppressed for faster iteration
- Nullable warnings disabled
- Security scanning now enabled (CodeQL, MSDO, vulnerability checks)

1. **Cross-Platform Considerations**
   - Scripts check for WSL environment and handle path conversions
   - PowerShell scripts use WindowsPath from config
   - Bash scripts use WSLPath from config
   - This avoids WSL file permission issues

2. **Versioning Strategy**
   - Uses Nerdbank.GitVersioning for deterministic SemVer 2.0 versioning
   - Format: `MAJOR.MINOR.PATCH[-PRERELEASE]+[BUILDMETADATA]`
   - Automatic version incrementing based on branch names

3. **Branch Publishing Strategy**
   - master → stable packages
   - develop → alpha packages  
   - feature/* → feature-specific packages
   - release/* → release candidate packages

4. **Security Features**
   - CodeQL analysis on every push
   - Microsoft Security DevOps scanning
   - Trivy vulnerability scanning
   - Dependabot for dependency updates
   - SBOM generation for releases

5. **Environment Protection**
   - Production environment for master/tags
   - Development environment for other branches
   - Requires manual approval for production deployments

## Development Guidelines

1. Always maintain cross-platform compatibility in scripts
2. Use existing configuration structure - don't hardcode values
3. Follow the established branch naming conventions (master, develop, feature/*, release/*)
4. Ensure all new workflows use least-privilege permissions
5. Test scripts in both PowerShell and Bash environments
6. Keep documentation up-to-date when adding new features

## Testing Approach

There are no automated tests for the scripts themselves. Testing is done manually by:
1. Running scripts in both PowerShell and Bash environments
2. Verifying repository creation and configuration
3. Checking that GitHub Actions workflows execute successfully
4. Ensuring idempotent operations (safe to re-run)

## Key Files to Understand

- `scripts/*/new-repo.*`: Main repository creation logic
- `workflows/dotnet-ci-cd.yml`: Complete CI/CD pipeline implementation
- `docs/scripts.md`: Comprehensive script documentation
- Configuration handling in all scripts (look for config read/write functions)

## Environment Variables and Configuration

The workflows use these environment variables to optimize .NET builds:
- `DOTNET_SKIP_FIRST_TIME_EXPERIENCE: true`
- `DOTNET_NOLOGO: true`
- `DOTNET_CLI_TELEMETRY_OPTOUT: true`
- `NUGET_XMLDOC_MODE: skip`

## Workflow Permissions

All workflows follow least-privilege principles:
- Default: `contents: read`
- Package publishing: `packages: write`
- Security scanning: `security-events: write`
- Issue creation: `issues: write`
- Azure OIDC: `id-token: write`