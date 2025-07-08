# Testing and Verification Guide

## Overview

This document provides testing and verification procedures for the CI/CD workflows repository after the recent reorganization and Azure DevOps integration.

## Changes Made

### 1. Repository Structure Reorganization
- Created `scripts/github/` directory for GitHub-specific scripts
- Created `scripts/azure/` directory for Azure DevOps-specific scripts
- Moved existing bash and PowerShell scripts into appropriate subdirectories
- Updated all relative paths in scripts to reflect new structure

### 2. Azure DevOps Integration
- Created Azure Pipelines YAML files in `pipelines/` directory
- Developed Azure DevOps setup scripts for repository creation
- Added Azure Artifacts feed integration
- Implemented Azure Key Vault integration scripts

## Testing Procedures

### 1. GitHub Scripts Testing

#### Bash Scripts (Linux/macOS/WSL)
```bash
# Test configuration creation
cd scripts/github/bash
./new-repo.sh --help

# Test repository creation (dry run)
# Note: This will prompt for configuration if not exists
./new-repo.sh test-repo-github

# Verify paths are correct
grep -n "CONFIG_FILE" new-repo.sh
grep -n "workflow_dir" new-repo.sh
```

#### PowerShell Scripts (Windows)
```powershell
# Test configuration creation
cd scripts\github\powershell
.\New-Repo.ps1 -?

# Test repository creation (dry run)
.\New-Repo.ps1 test-repo-github

# Verify paths are correct
Select-String "ConfigPath" New-Repo.ps1
Select-String "workflowDir" New-Repo.ps1
```

### 2. Azure DevOps Scripts Testing

#### Prerequisites
- Azure CLI installed and authenticated (`az login`)
- Azure DevOps extension installed (`az extension add --name azure-devops`)
- Appropriate permissions in Azure DevOps organization

#### Bash Scripts Testing
```bash
# Test Azure DevOps repository creation
cd scripts/azure/bash
./new-repo.sh --help

# Test configuration (will prompt if not exists)
./new-repo.sh test-repo-azure

# Test Key Vault integration
./add-azure-keyvault.sh --help
```

#### PowerShell Scripts Testing
```powershell
# Test Azure DevOps repository creation
cd scripts\azure\powershell
.\New-Repo.ps1 -?

# Test configuration
.\New-Repo.ps1 test-repo-azure

# Test Key Vault integration
.\Add-AzureKeyVault.ps1 -?
```

### 3. Pipeline Files Verification

#### Validate YAML Syntax
```bash
# Install yamllint if not already installed
pip install yamllint

# Validate pipeline files
yamllint pipelines/*.yml
```

#### Manual Pipeline Validation
1. Create a test repository in Azure DevOps
2. Copy pipeline files to the repository
3. Create a pipeline using the YAML files
4. Run pipeline in validation mode

### 4. Path Verification Tests

#### GitHub Scripts Path Tests
```bash
# From repository root
# Test that scripts can find config.json
scripts/github/bash/new-repo.sh --help

# Test that scripts can find workflow templates
ls -la workflows/
```

#### Azure Scripts Path Tests
```bash
# From repository root
# Test that scripts can find config.json
scripts/azure/bash/new-repo.sh --help

# Test that scripts can find pipeline templates
ls -la pipelines/
```

## Verification Checklist

### Pre-Commit Verification
- [ ] All bash scripts have executable permissions (may show errors in WSL)
- [ ] All relative paths updated correctly
- [ ] No hardcoded paths remaining
- [ ] Configuration file paths work from new locations
- [ ] Workflow/pipeline template references are correct

### Post-Commit Verification
- [ ] GitHub scripts create repositories successfully
- [ ] Azure DevOps scripts create repositories successfully
- [ ] Pipelines can be imported into Azure DevOps
- [ ] Key Vault integration scripts work correctly
- [ ] All documentation is up to date

## Known Issues and Limitations

### WSL File Permissions
- chmod may fail on Windows-mounted drives in WSL
- Scripts will still execute despite permission warnings
- This is a known WSL limitation and doesn't affect functionality

### Azure DevOps API Limitations
- Some operations require manual steps in Azure DevOps portal
- Branch policies API has limited functionality
- Service connections must be created manually
- Variable group Key Vault linking requires portal configuration

### Configuration File Location
- Config file is shared between GitHub and Azure scripts
- Located at repository root level (config.json)
- Scripts will create it on first run if missing

## Troubleshooting

### Common Issues

1. **Script not found**
   - Ensure you're in the correct directory
   - Check file permissions (especially on Linux/macOS)
   - Verify paths in error messages

2. **Configuration errors**
   - Delete config.json and let script recreate it
   - Verify JSON syntax if manually edited
   - Check for proper escaping in paths

3. **Azure CLI errors**
   - Ensure logged in: `az login`
   - Check subscription: `az account show`
   - Install DevOps extension: `az extension add --name azure-devops`

4. **Path resolution errors**
   - Scripts expect to be run from their directory
   - Use absolute paths when in doubt
   - Check PWD before running scripts

## Future Improvements

1. Add automated testing suite
2. Create Docker container for consistent testing environment
3. Implement CI/CD for the CI/CD scripts themselves
4. Add more robust error handling and logging
5. Create unified configuration management

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review script help: `script-name --help`
3. Check Azure DevOps documentation for API limitations
4. Submit issues to the repository issue tracker