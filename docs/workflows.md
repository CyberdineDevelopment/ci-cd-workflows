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