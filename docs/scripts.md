# Script Documentation

## Setup Scripts

### setup-cicd-repos.sh / Setup-CICDRepos.ps1

Creates new repositories with complete CI/CD configuration.

**Features:**
- Creates private GitHub repositories
- Configures Nerdbank.GitVersioning
- Sets up GitHub Actions workflows
- Configures branch protection
- Creates staging/production environments

**Usage:**
```bash
./setup-cicd-repos.sh
```

### update-repos.sh / Update-Repos.ps1

Updates existing repositories with latest CI/CD configurations.

**Options:**
- `--all` - Update all organization repositories
- `--workflows-only` - Update only workflow files
- `--config-only` - Update only configuration files
- `--fix-branch` - Fix default branch to master
- `--add-repo NAME` - Add a new repository

**Examples:**
```bash
# Update specific repositories
./update-repos.sh smart-generators enhanced-enums

# Update all repositories
./update-repos.sh --all

# Add a new repository
./update-repos.sh --add-repo new-library
```

### add-azure-keyvault.sh / Add-AzureKeyVault.ps1

Adds Azure Key Vault integration to repositories.

**Features:**
- Creates Azure Key Vault workflow
- Configures OIDC authentication
- Sets up secret retrieval

**Requirements:**
- Azure CLI (for resource creation)
- Azure service principal
- Organization secrets:
  - AZURE_CLIENT_ID
  - AZURE_TENANT_ID
  - AZURE_SUBSCRIPTION_ID

### create-cicd-workflows-repo.sh / Create-CICDWorkflowsRepo.ps1

Creates this ci-cd-workflows repository and copies all scripts.

**Features:**
- Creates repository structure
- Copies all scripts
- Adds documentation
- Optionally creates test repository

### setup-all.sh

Master setup script that orchestrates the entire CI/CD setup.

**Features:**
- Runs create-cicd-workflows-repo.sh
- Optionally creates all repositories
- Provides clear next steps

## Script Configuration

All scripts share common configuration:
- **Organization**: cyberdinedevelopment
- **Default Path**: /mnt/d/fractaldataworks (bash) or D:\fractaldataworks (PowerShell)
- **Default Branch**: master
- **Repository Visibility**: private (configurable)

## Error Handling

Scripts include:
- Dependency checking
- Authentication validation
- Idempotent operations (safe to re-run)
- Clear error messages
- Colored output for better readability