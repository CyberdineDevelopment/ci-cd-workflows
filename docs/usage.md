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