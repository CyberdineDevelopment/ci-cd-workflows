# Script Documentation

## Overview

This repository contains scripts for setting up CI/CD workflows on both GitHub and Azure DevOps platforms. Scripts are organized by platform and language:

- `scripts/github/` - GitHub Actions workflows and repository setup
- `scripts/azure/` - Azure DevOps pipelines and repository setup

## GitHub Scripts

### GitHub: new-repo.sh / New-Repo.ps1 (Recommended)

Creates a single new repository with complete CI/CD configuration. **Best for most use cases.**

**Features:**
- Interactive configuration setup on first run
- Creates private/public GitHub repository
- Sets up complete CI/CD workflows
- Configures Nerdbank.GitVersioning
- Supports multi-branch publishing (develop, feature/, release/)
- Cross-platform compatibility

**Usage:**
```bash
# Navigate to scripts directory
cd scripts/github/bash

# Create new repository (prompts for config on first run)
./new-repo.sh my-awesome-library

# Override license
./new-repo.sh my-library --license MIT

# Use custom config file
./new-repo.sh my-library --config ../config.json
```

**PowerShell:**
```powershell
# Navigate to scripts directory
cd scripts\github\powershell

# Create new repository
.\New-Repo.ps1 my-awesome-library

# Override license
.\New-Repo.ps1 my-library -License MIT

# Use custom config
.\New-Repo.ps1 my-library -ConfigPath "..\config.json"
```

### setup-all.sh / Setup-All.ps1

Master setup scripts that orchestrate complete CI/CD infrastructure setup.

**Features:**
- Interactive configuration management
- Creates ci-cd-workflows repository structure
- Optionally creates multiple predefined repositories
- Provides comprehensive setup overview

**Usage:**
```bash
# Complete infrastructure setup
./setup-all.sh

# Force reconfiguration
./setup-all.sh --reconfigure

# Use custom config file
./setup-all.sh --config "/path/to/config.json"
```

**PowerShell:**
```powershell
# Complete setup
.\Setup-All.ps1

# Force reconfiguration
.\Setup-All.ps1 -ReconfigureAll

# Custom config path
.\Setup-All.ps1 -ConfigPath "C:\MyConfig\config.json"
```

### setup-cicd-repos.sh / Setup-CICDRepos.ps1

Creates multiple predefined repositories for a complete development toolkit.

**Features:**
- Creates 5 repositories: smart-generators, enhanced-enums, smart-switches, smart-delegates, developer-kit
- Uses existing configuration
- Sets up all repositories with identical CI/CD configuration

**Usage:**
```bash
./setup-cicd-repos.sh
```

**PowerShell:**
```powershell
.\Setup-CICDRepos.ps1
```

### add-azure-keyvault.sh / Add-AzureKeyVault.ps1

Adds Azure Key Vault integration to existing repositories.

**Features:**
- Creates Azure Key Vault workflow
- Configures OIDC authentication
- Sets up secret retrieval for CI/CD

**Requirements:**
- Azure CLI (optional, for resource creation)
- Azure service principal
- Organization secrets: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID

**Usage:**
```bash
./add-azure-keyvault.sh
```

**PowerShell:**
```powershell
.\Add-AzureKeyVault.ps1
```

## Configuration Structure

All scripts use a shared configuration file (`config.json`):

```json
{
  "GitHubOrganization": "your-github-org",
  "CompanyName": "YourCompany",
  "WSLPath": "/home/user/projects", 
  "WindowsPath": "D:\\fractaldataworks",
  "DefaultBranch": "master",
  "RepositoryVisibility": "private",
  "DefaultLicense": "Apache-2.0"
}
```

### Configuration Options

- **GitHubOrganization**: GitHub organization name (used for repository URLs)
- **CompanyName**: Company name (used for package names, copyright)
- **WSLPath**: Local path where repositories are cloned when using bash scripts
- **WindowsPath**: Local path where repositories are cloned when using PowerShell scripts
- **RepositoryVisibility**: "private" or "public"
- **DefaultBranch**: "master" (recommended, never "main")
- **DefaultLicense**: "Apache-2.0" or "MIT"

## Script Features

### Auto-Configuration
- **First run**: Scripts prompt for configuration and save it (includes both WSL and Windows paths)
- **Subsequent runs**: Use saved configuration automatically (bash uses WSLPath, PowerShell uses WindowsPath)
- **Platform-specific paths**: Avoids WSL file permission issues by using appropriate filesystem paths
- **Reconfiguration**: Use `--reconfigure` flags to update settings

### Cross-Platform Support
- **Bash scripts**: Linux, macOS, WSL
- **PowerShell scripts**: Windows, PowerShell Core
- **Identical functionality** across platforms

### Error Handling
- Dependency checking (gh, git, dotnet)
- Authentication validation
- Idempotent operations (safe to re-run)
- Clear error messages with colored output

### Repository Features Created
- GitHub Actions workflows for CI/CD
- Nerdbank.GitVersioning with SemVer 2.0
- Multi-branch publishing (develop→alpha, feature/→feature-name, master→stable)
- Security scanning (CodeQL, MSDO, Trivy)
- SBOM generation
- Branch protection rules
- Environment-based deployments
- GitHub Packages integration
- Automated dependency updates

## Recommended Workflow

1. **First repository**: `./new-repo.sh my-first-library` (sets up config)
2. **Additional repositories**: `./new-repo.sh another-library` (uses existing config)
3. **Multiple repositories**: `./setup-cicd-repos.sh` (if you want the predefined set)
4. **Azure integration**: `./add-azure-keyvault.sh` (when needed)

## Migration from Legacy Scripts

Previous versions included `update-repos` and `create-cicd-workflows-repo` scripts that have been removed:

- **Instead of update-repos**: Use `new-repo` for new repositories
- **Instead of create-cicd-workflows-repo**: This repository already exists

The new approach is simpler and more reliable.

## Azure DevOps Scripts

### Azure: new-repo.sh / New-Repo.ps1

Creates a new Azure DevOps repository with complete CI/CD pipeline configuration.

**Features:**
- Interactive configuration setup on first run
- Creates Azure DevOps repository with pipelines
- Sets up Azure Artifacts feed (organization-scoped)
- Configures Nerdbank.GitVersioning
- Creates variable groups for environments
- Supports multi-branch publishing
- Cross-platform compatibility

**Usage:**
```bash
# Navigate to scripts directory
cd scripts/azure/bash

# Create new repository (prompts for config on first run)
./new-repo.sh my-awesome-library

# Override project
./new-repo.sh my-library --project MyProject

# Override organization
./new-repo.sh my-library --org MyOrg
```

**PowerShell:**
```powershell
# Navigate to scripts directory
cd scripts\azure\powershell

# Create new repository
.\New-Repo.ps1 my-awesome-library

# Override project
.\New-Repo.ps1 my-library -Project MyProject

# Override organization
.\New-Repo.ps1 my-library -Organization MyOrg
```

### Azure: add-azure-keyvault.sh / Add-AzureKeyVault.ps1

Integrates Azure Key Vault with Azure DevOps pipelines through variable groups.

**Features:**
- Creates service principal for Key Vault access
- Configures Key Vault permissions
- Creates variable groups linked to Key Vault
- Generates setup instructions
- Supports multiple environments

**Requirements:**
- Azure CLI installed and authenticated
- Azure subscription with Key Vault
- Appropriate permissions in Azure DevOps

**Usage:**
```bash
# Basic usage
./add-azure-keyvault.sh -k my-keyvault -g production-secrets

# With organization and project
./add-azure-keyvault.sh -k my-keyvault -g production-secrets -o MyOrg -p MyProject
```

**PowerShell:**
```powershell
# Basic usage
.\Add-AzureKeyVault.ps1 -KeyVaultName my-keyvault -VariableGroupName production-secrets

# With organization and project
.\Add-AzureKeyVault.ps1 -KeyVaultName my-keyvault -VariableGroupName production-secrets -Organization MyOrg -Project MyProject
```

## Azure DevOps Configuration

### Extended Configuration for Azure DevOps

The same `config.json` file supports Azure DevOps with additional fields:

```json
{
  "GitHubOrganization": "your-github-org",
  "AzureOrganization": "your-azure-org",
  "AzureProject": "your-project",
  "CompanyName": "YourCompany",
  "WSLPath": "/home/user/projects", 
  "WindowsPath": "D:\\fractaldataworks",
  "DefaultBranch": "master",
  "RepositoryVisibility": "private",
  "DefaultLicense": "Apache-2.0",
  "ArtifactFeed": "dotnet-packages"
}
```

### Azure-Specific Configuration Options

- **AzureOrganization**: Azure DevOps organization name
- **AzureProject**: Default Azure DevOps project
- **ArtifactFeed**: Azure Artifacts feed name (organization-scoped)

## Pipeline Files

### Azure Pipelines

Located in `pipelines/` directory:

- **dotnet-ci-cd.yml**: Main CI/CD pipeline with multi-stage builds
- **security.yml**: Weekly security scanning pipeline
- **azure-keyvault.yml**: Reusable template for Key Vault integration

### Features of Azure Pipelines

- Multi-version .NET support (9.0, 10.0)
- Parallel builds with matrix strategy
- Azure Artifacts integration (organization-scoped)
- Key Vault secret management
- Security scanning (Microsoft Security DevOps)
- SBOM generation with CycloneDX
- Environment-based deployments
- Variable groups for configuration
- Conditional NuGet.org publishing

## Platform Comparison

### GitHub Actions vs Azure Pipelines

| Feature | GitHub Actions | Azure Pipelines |
|---------|---------------|-----------------|
| Hosting | GitHub cloud | Azure DevOps |
| Package Registry | GitHub Packages | Azure Artifacts |
| Secret Management | GitHub Secrets | Azure Key Vault |
| Security Scanning | CodeQL, Dependabot | MS Security DevOps |
| Environments | GitHub Environments | Azure Environments |
| Approval Gates | Environment protection | Stage approvals |
| OIDC Auth | Yes | Yes |
| Self-hosted runners | Yes | Yes (agents) |

### Choosing Between Platforms

**Use GitHub Actions when:**
- Your code is hosted on GitHub
- You want integrated security scanning with CodeQL
- You prefer GitHub's ecosystem
- You need public package hosting

**Use Azure DevOps when:**
- You're in the Microsoft ecosystem
- You need enterprise features
- You want integrated work item tracking
- You prefer Azure's security model
- You need organization-scoped artifact feeds

## Migration Guide

### From GitHub to Azure DevOps

1. Run Azure setup script to create repository
2. Push existing code to Azure Repos
3. Variable groups replace GitHub secrets
4. Azure Artifacts replaces GitHub Packages
5. Update package references in consuming projects

### From Azure DevOps to GitHub

1. Run GitHub setup script to create repository
2. Push existing code to GitHub
3. Create GitHub secrets from Key Vault values
4. Update package source to GitHub Packages
5. Configure Dependabot for security updates