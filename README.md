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

### Complete Setup (Recommended)

For first-time setup with configuration management:

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

### Create New Repositories Only

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

## Configuration Management

The setup scripts now support configuration management:

- **Organization name**: Your GitHub organization
- **Default path**: Where repositories are cloned
- **Repository visibility**: Private or public repositories
- **Default branch**: Branch name (typically 'master' or 'main')

Configuration is saved to `config.json` (gitignored) and reused for subsequent runs.

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