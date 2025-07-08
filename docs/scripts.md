# Script Documentation

## Available Scripts

### new-repo.sh / New-Repo.ps1 (Recommended)

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
# Create new repository (prompts for config on first run)
./new-repo.sh my-awesome-library

# Override license
./new-repo.sh my-library --license MIT

# Use custom config file
./new-repo.sh my-library --config ../config.json
```

**PowerShell:**
```powershell
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