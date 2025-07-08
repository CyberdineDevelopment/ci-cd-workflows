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

### Create a Single Repository (Recommended)

The easiest way to create a new .NET repository with full CI/CD:

**Bash (Linux/macOS/WSL):**
```bash
cd scripts/bash
./new-repo.sh my-awesome-library
```

**PowerShell (Windows):**
```powershell
cd scripts\powershell
.\New-Repo.ps1 my-awesome-library
```

*On first run, you'll be prompted to configure your organization settings.*

### Complete Setup with Multiple Repositories

For setting up the entire CI/CD infrastructure and multiple repositories:

**Bash (Linux/macOS/WSL):**
```bash
cd scripts/bash
./setup-all.sh
```

**PowerShell (Windows):**
```powershell
cd scripts\powershell
.\Setup-All.ps1
```

## Configuration Management

The scripts support configuration management with automatic setup:

- **GitHub Organization**: Your GitHub organization name
- **Company Name**: Used for package names and copyright
- **WSL Path**: Where repositories are cloned when using bash scripts (WSL filesystem)
- **Windows Path**: Where repositories are cloned when using PowerShell scripts
- **Repository Visibility**: Private or public repositories  
- **Default Branch**: Branch name (always 'master', never 'main')
- **Default License**: Apache-2.0 or MIT

**First-time behavior**: Scripts will prompt you for configuration including both WSL and Windows paths, saving to `config.json` (gitignored).  
**Subsequent runs**: Use the saved configuration automatically - bash scripts use WSLPath, PowerShell scripts use WindowsPath.

**Cross-platform note**: This dual-path approach avoids WSL file permission issues while allowing you to work with your preferred directory structure on both platforms.

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
- Apache-2.0 license (can be changed to MIT)
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

Apache-2.0