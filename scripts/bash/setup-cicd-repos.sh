#!/bin/bash
# setup-cicd-repos.sh - Complete CI/CD setup for multiple .NET repositories
# Organization: cyberdinedevelopment

set -e

# Configuration
ORG_NAME="cyberdinedevelopment"
DEFAULT_PATH="/mnt/d/fractaldataworks"
DEFAULT_BRANCH="master"
DOTNET_VERSION="9.0"
NBGV_VERSION="3.6.*"

# Repositories to create
REPOSITORIES=(
    "smart-generators"
    "enhanced-enums"
    "smart-switches"
    "smart-delegates"
    "developer-kit"
)

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    local deps=("gh" "git" "dotnet" "jq")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "$dep is not installed"
            exit 1
        fi
    done
    
    # Check GitHub authentication
    if ! gh auth status &> /dev/null; then
        log_error "Not authenticated with GitHub. Run 'gh auth login' first."
        exit 1
    fi
    
    log_info "All dependencies satisfied"
}

# Create and configure repository
create_repository() {
    local repo_name="$1"
    local description="$2"
    
    log_info "Creating repository: $ORG_NAME/$repo_name"
    
    # Create repository
    cd "$DEFAULT_PATH"
    
    # Create without --default-branch since it's not supported
    if gh repo create "$ORG_NAME/$repo_name" \
        --private \
        --description "$description" \
        --gitignore "VisualStudio" \
        --license "MIT" \
        --confirm; then
        
        # Clone the repository
        gh repo clone "$ORG_NAME/$repo_name"
        
        # Change default branch if needed
        if [[ "$DEFAULT_BRANCH" != "main" ]]; then
            cd "$DEFAULT_PATH/$repo_name"
            git checkout -b "$DEFAULT_BRANCH"
            git push -u origin "$DEFAULT_BRANCH"
            
            # Set default branch on GitHub
            gh repo edit "$ORG_NAME/$repo_name" --default-branch "$DEFAULT_BRANCH"
            
            # Delete main branch
            git push origin --delete main 2>/dev/null || true
        fi
    else
        log_warn "Repository may already exist, attempting to clone..."
        gh repo clone "$ORG_NAME/$repo_name" || return 1
    fi
    
    cd "$DEFAULT_PATH/$repo_name"
    
    # Configure repository settings
    log_info "Configuring repository settings..."
    gh repo edit "$ORG_NAME/$repo_name" \
        --enable-issues \
        --enable-wiki \
        --enable-discussions \
        --enable-projects \
        --enable-auto-merge \
        --enable-squash-merge \
        --enable-rebase-merge \
        --delete-branch-on-merge \
        --add-topic "dotnet,csharp,nuget" || log_warn "Some settings may not have been applied"
}

# Setup branch protection
setup_branch_protection() {
    local repo_name="$1"
    
    log_info "Setting up branch protection for $DEFAULT_BRANCH branch"
    
    # Wait for branch to be available
    sleep 2
    
    gh api --method PUT "repos/$ORG_NAME/$repo_name/branches/$DEFAULT_BRANCH/protection" \
        --raw-field 'required_status_checks={"strict":true,"contexts":["build","test","security"]}' \
        --raw-field 'required_pull_request_reviews={"required_approving_review_count":1,"dismiss_stale_reviews":true,"require_code_owner_reviews":true}' \
        --raw-field 'enforce_admins=false' \
        --raw-field 'required_linear_history=true' \
        --raw-field 'allow_force_pushes=false' \
        --raw-field 'allow_deletions=false' \
        --raw-field 'required_conversation_resolution=true' \
        --raw-field 'lock_branch=false' \
        --raw-field 'allow_fork_syncing=true' 2>/dev/null || log_warn "Branch protection partially applied"
}

# Setup GitHub environments
setup_environments() {
    local repo_name="$1"
    
    log_info "Setting up deployment environments"
    
    # Create staging environment
    gh api --method PUT "repos/$ORG_NAME/$repo_name/environments/staging" \
        --field "wait_timer=0" \
        --field "deployment_branch_policy=null" || log_warn "Staging environment setup failed"
    
    # Create production environment with protection
    gh api --method PUT "repos/$ORG_NAME/$repo_name/environments/production" \
        --field "wait_timer=30" \
        --field "deployment_branch_policy[protected_branches]=true" \
        --field "deployment_branch_policy[custom_branch_policies]=false" || log_warn "Production environment setup failed"
}

# Setup secrets
setup_secrets() {
    local repo_name="$1"
    
    log_info "Setting up repository secrets"
    
    # Repository-level secrets
    echo "dummy-key-replace-in-production" | gh secret set NUGET_API_KEY --repo "$ORG_NAME/$repo_name" || true
    
    # Environment-specific secrets
    echo "staging-connection-string" | gh secret set DATABASE_URL --repo "$ORG_NAME/$repo_name" --env staging || true
    echo "production-connection-string" | gh secret set DATABASE_URL --repo "$ORG_NAME/$repo_name" --env production || true
}

# Create project files
create_project_files() {
    local repo_name="$1"
    local repo_path="$DEFAULT_PATH/$repo_name"
    
    cd "$repo_path"
    
    # Create directory structure
    mkdir -p .github/workflows
    mkdir -p src
    mkdir -p tests
    mkdir -p docs
    mkdir -p .config
    
    # Create .gitignore
    cat > .gitignore << 'EOF'
## Ignore Visual Studio temporary files, build results, and
## files generated by popular Visual Studio add-ons.

# User-specific files
*.rsuser
*.suo
*.user
*.userosscache
*.sln.docstates

# Build results
[Dd]ebug/
[Dd]ebugPublic/
[Rr]elease/
[Rr]eleases/
x64/
x86/
[Ww][Ii][Nn]32/
[Aa][Rr][Mm]/
[Aa][Rr][Mm]64/
bld/
[Bb]in/
[Oo]bj/
[Ll]og/
[Ll]ogs/

# Visual Studio 2015/2017 cache/options directory
.vs/

# .NET Core
project.lock.json
project.fragment.lock.json
artifacts/

# Files built by Visual Studio
*.obj
*.pdb
*.tmp
*.tmp_proj
*_wpftmp.csproj
*.log
*.vspscc
*.vssscc
.builds
*.pidb
*.svclog
*.scc

# NuGet Packages
*.nupkg
*.snupkg
# The packages folder can be ignored because of Package Restore
**/[Pp]ackages/*
# except build/, which is used as an MSBuild target.
!**/[Pp]ackages/build/
# NuGet v3's project.json files produces more ignorable files
*.nuget.props
*.nuget.targets

# Visual Studio cache files
# files ending in .cache can be ignored
*.[Cc]ache
# but keep track of directories ending in .cache
!?*.[Cc]ache/

# Others
ClientBin/
~$*
*~
*.dbmdl
*.dbproj.schemaview
*.jfm
*.pfx
*.publishsettings
orleans.codegen.cs

# ReSharper
_ReSharper*/
*.[Rr]e[Ss]harper
*.DotSettings.user

# JetBrains Rider
.idea/
*.sln.iml

# Coverage
*.coverage
*.coveragexml
coverage.json
coverage.opencover.xml

# Publish output
publish/
EOF

    # Create global.json
    cat > global.json << EOF
{
  "sdk": {
    "version": "${DOTNET_VERSION}",
    "rollForward": "latestFeature",
    "allowPrerelease": false
  }
}
EOF

    # Create Directory.Build.props
    cat > Directory.Build.props << 'EOF'
<Project>
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <LangVersion>latest</LangVersion>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
    <NoWarn>$(NoWarn);CS1591</NoWarn>
    
    <!-- Package properties -->
    <Authors>CyberDine Development</Authors>
    <Company>CyberDine Development</Company>
    <Copyright>Copyright (c) CyberDine Development $([System.DateTime]::Now.Year)</Copyright>
    <PackageLicenseExpression>MIT</PackageLicenseExpression>
    <RepositoryUrl>https://github.com/cyberdinedevelopment/$(MSBuildProjectName)</RepositoryUrl>
    <RepositoryType>git</RepositoryType>
    <PublishRepositoryUrl>true</PublishRepositoryUrl>
    <EmbedUntrackedSources>true</EmbedUntrackedSources>
    <IncludeSymbols>true</IncludeSymbols>
    <SymbolPackageFormat>snupkg</SymbolPackageFormat>
    
    <!-- Source Link -->
    <ContinuousIntegrationBuild Condition="'$(GITHUB_ACTIONS)' == 'true'">true</ContinuousIntegrationBuild>
    <Deterministic>true</Deterministic>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.SourceLink.GitHub" Version="8.0.*" PrivateAssets="All"/>
    <PackageReference Include="Nerdbank.GitVersioning" Version="3.6.*" PrivateAssets="all" />
  </ItemGroup>
</Project>
EOF

    # Create .editorconfig
    cat > .editorconfig << 'EOF'
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
indent_style = space
indent_size = 4
trim_trailing_whitespace = true

[*.{cs,csx,vb,vbx}]
indent_size = 4

[*.{csproj,vbproj,vcxproj,vcxproj.filters,proj,projitems,shproj}]
indent_size = 2

[*.{json,yml,yaml}]
indent_size = 2

[*.md]
trim_trailing_whitespace = false
EOF

    # Create nuget.config
    cat > nuget.config << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
    <add key="github" value="https://nuget.pkg.github.com/cyberdinedevelopment/index.json" />
  </packageSources>
  <packageSourceMapping>
    <packageSource key="nuget.org">
      <package pattern="*" />
    </packageSource>
    <packageSource key="github">
      <package pattern="CyberDine.*" />
    </packageSource>
  </packageSourceMapping>
</configuration>
EOF

    # Create version.json for Nerdbank.GitVersioning
    cat > version.json << 'EOF'
{
  "$schema": "https://raw.githubusercontent.com/dotnet/Nerdbank.GitVersioning/master/src/NerdBank.GitVersioning/version.schema.json",
  "version": "1.0-alpha",
  "publicReleaseRefSpec": [
    "^refs/heads/master$",
    "^refs/tags/v\\d+\\.\\d+"
  ],
  "cloudBuild": {
    "buildNumber": {
      "enabled": true,
      "includeCommitId": {
        "when": "nonPublicReleaseOnly",
        "where": "buildMetadata"
      }
    },
    "setAllVariables": true
  },
  "release": {
    "branchName": "release/v{version}",
    "versionIncrement": "minor",
    "firstUnstableTag": "alpha"
  },
  "inherit": false
}
EOF

    # Create SECURITY.md
    cat > SECURITY.md << 'EOF'
# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

Please report security vulnerabilities by emailing security@cyberdinedevelopment.com

We will acknowledge receipt within 48 hours and provide a detailed response within 7 days.

## Security Update Policy

Security updates are released as soon as possible after a vulnerability is confirmed.
EOF

    # Create README.md
    cat > README.md << EOF
# $repo_name

Part of the CyberDine Development toolkit.

## Build Status

[![.NET CI/CD Pipeline](https://github.com/$ORG_NAME/$repo_name/actions/workflows/dotnet-ci-cd.yml/badge.svg)](https://github.com/$ORG_NAME/$repo_name/actions/workflows/dotnet-ci-cd.yml)

## Installation

\`\`\`bash
dotnet add package CyberDine.$repo_name
\`\`\`

## Development

This repository contains library packages for .NET development. To use these packages:

1. Reference the package in your project
2. Follow the documentation in the /docs folder
3. See examples in the /samples folder (if available)

## License

MIT
EOF

    # Create .github/dependabot.yml
    cat > .github/dependabot.yml << 'EOF'
version: 2
updates:
  - package-ecosystem: "nuget"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    open-pull-requests-limit: 5
    groups:
      production-dependencies:
        patterns:
          - "*"
        exclude-patterns:
          - "*.Test*"
          - "xunit*"
          - "coverlet*"
    
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
EOF

    # Create .github/CODEOWNERS
    cat > .github/CODEOWNERS << 'EOF'
# Default owners
* @cyberdinedevelopment/developers

# CI/CD and build configuration
/.github/ @cyberdinedevelopment/devops
/*.props @cyberdinedevelopment/devops
/*.targets @cyberdinedevelopment/devops

# Security-sensitive files
/src/**/Security/ @cyberdinedevelopment/security
/src/**/Authentication/ @cyberdinedevelopment/security
SECURITY.md @cyberdinedevelopment/security
EOF

    # Create main CI/CD workflow
    cat > .github/workflows/dotnet-ci-cd.yml << 'EOF'
name: .NET CI/CD Pipeline

on:
  push:
    branches: [ master, develop ]
    tags: [ 'v*' ]
  pull_request:
    branches: [ master ]
  workflow_dispatch:

env:
  DOTNET_VERSION: '9.0.x'
  DOTNET_SKIP_FIRST_TIME_EXPERIENCE: 'true'
  DOTNET_NOLOGO: 'true'
  DOTNET_CLI_TELEMETRY_OPTOUT: 'true'
  NUGET_XMLDOC_MODE: 'skip'

jobs:
  build:
    name: Build and Test
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      
    steps:
    - name: Checkout
      uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: Setup .NET
      uses: actions/setup-dotnet@v4
      with:
        dotnet-version: |
          9.0.x
          10.0.x
        cache: true
        cache-dependency-path: '**/packages.lock.json'

    - name: Install tools
      run: |
        dotnet tool restore
        dotnet tool install --global nbgv

    - name: Set version
      id: nbgv
      uses: dotnet/nbgv@v0.4.2
      with:
        setAllVars: true

    - name: Display version
      run: |
        echo "Version: ${{ steps.nbgv.outputs.Version }}"
        echo "SemVer2: ${{ steps.nbgv.outputs.SemVer2 }}"
        echo "NuGet Version: ${{ steps.nbgv.outputs.NuGetPackageVersion }}"
        nbgv get-version

    - name: Restore dependencies
      run: dotnet restore --locked-mode

    - name: Build
      run: dotnet build --configuration Release --no-restore

    - name: Test
      run: |
        if [ -d "tests" ] && [ "$(ls -A tests)" ]; then
          dotnet test --configuration Release --no-build --verbosity normal --collect:"XPlat Code Coverage" --results-directory ./coverage
        else
          echo "No tests found, skipping test step"
        fi

    - name: Generate coverage report
      if: ${{ hashFiles('tests/**/*.csproj') != '' }}
      uses: danielpalme/ReportGenerator-GitHub-Action@5.2.0
      with:
        reports: coverage/**/coverage.cobertura.xml
        targetdir: coverage/report
        reporttypes: 'HtmlInline;Cobertura;MarkdownSummaryGithub'

    - name: Upload coverage reports
      if: ${{ hashFiles('tests/**/*.csproj') != '' }}
      uses: actions/upload-artifact@v4
      with:
        name: coverage-report
        path: coverage/report

    - name: Create NuGet package
      if: github.ref == 'refs/heads/master' || startsWith(github.ref, 'refs/tags/v')
      run: |
        if [ -d "src" ] && [ "$(ls -A src)" ]; then
          dotnet pack --configuration Release --no-build --output ./artifacts
        else
          echo "No source projects found, skipping pack step"
        fi

    - name: Upload artifacts
      if: (github.ref == 'refs/heads/master' || startsWith(github.ref, 'refs/tags/v')) && hashFiles('src/**/*.csproj') != ''
      uses: actions/upload-artifact@v4
      with:
        name: nuget-packages
        path: ./artifacts/*.nupkg

  security:
    name: Security Scan
    runs-on: ubuntu-latest
    permissions:
      actions: read
      contents: read
      security-events: write
      
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Initialize CodeQL
      uses: github/codeql-action/init@v3
      with:
        languages: csharp

    - name: Setup .NET
      uses: actions/setup-dotnet@v4
      with:
        dotnet-version: '9.0.x'

    - name: Build for CodeQL
      run: |
        if [ -d "src" ] && [ "$(ls -A src)" ]; then
          dotnet build --configuration Release
        else
          echo "No source projects found, creating dummy project for CodeQL"
          mkdir -p temp
          cd temp
          dotnet new classlib -n TempLib
          dotnet build
          cd ..
        fi

    - name: Perform CodeQL Analysis
      uses: github/codeql-action/analyze@v3

    - name: Run Microsoft Security DevOps
      uses: microsoft/security-devops-action@v1
      id: msdo
      continue-on-error: true

    - name: Upload MSDO results
      if: steps.msdo.outputs.sarifFile != ''
      uses: github/codeql-action/upload-sarif@v3
      with:
        sarif_file: ${{ steps.msdo.outputs.sarifFile }}

    - name: Check for vulnerable packages
      run: |
        dotnet restore
        dotnet list package --vulnerable --include-transitive 2>&1 | tee vulnerable.txt
        ! grep -q "has the following vulnerable packages" vulnerable.txt

  publish:
    name: Publish Package
    needs: [build, security]
    if: (github.ref == 'refs/heads/master' || startsWith(github.ref, 'refs/tags/v')) && github.event.repository.name != 'ci-cd-workflows'
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://github.com/cyberdinedevelopment/${{ github.event.repository.name }}/packages
    permissions:
      contents: read
      packages: write
      
    steps:
    - name: Download artifacts
      uses: actions/download-artifact@v4
      with:
        name: nuget-packages
        path: ./artifacts

    - name: Setup .NET
      uses: actions/setup-dotnet@v4
      with:
        dotnet-version: '9.0.x'

    - name: Publish to GitHub Packages
      run: |
        dotnet nuget push "./artifacts/*.nupkg" \
          --source "https://nuget.pkg.github.com/cyberdinedevelopment/index.json" \
          --api-key ${{ secrets.GITHUB_TOKEN }} \
          --skip-duplicate

    - name: Publish to NuGet.org
      if: startsWith(github.ref, 'refs/tags/v')
      run: |
        dotnet nuget push "./artifacts/*.nupkg" \
          --source "https://api.nuget.org/v3/index.json" \
          --api-key ${{ secrets.NUGET_API_KEY }} \
          --skip-duplicate
EOF

    # Create security workflow
    cat > .github/workflows/security.yml << 'EOF'
name: Security Scanning

on:
  schedule:
    - cron: '0 8 * * 1'  # Weekly on Monday
  workflow_dispatch:

jobs:
  scan:
    name: Security Audit
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write
      issues: write
      
    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Setup .NET
      uses: actions/setup-dotnet@v4
      with:
        dotnet-version: '9.0.x'

    - name: Check for vulnerable packages
      run: |
        dotnet restore
        dotnet list package --vulnerable --include-transitive > vulnerable-packages.txt
        if grep -q "has the following vulnerable packages" vulnerable-packages.txt; then
          echo "::error::Vulnerable packages found"
          cat vulnerable-packages.txt
          
          # Create issue if vulnerabilities found
          gh issue create \
            --title "Security: Vulnerable packages detected" \
            --body "$(cat vulnerable-packages.txt)" \
            --label "security,dependencies"
          exit 1
        fi

    - name: Run Trivy security scanner
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        scan-ref: '.'
        format: 'sarif'
        output: 'trivy-results.sarif'
        severity: 'CRITICAL,HIGH'

    - name: Upload Trivy results
      uses: github/codeql-action/upload-sarif@v3
      with:
        sarif_file: 'trivy-results.sarif'

    - name: SBOM Generation
      uses: CycloneDX/gh-dotnet-generate-sbom@v1
      with:
        path: './'
        json: true
        github-bearer-token: ${{ secrets.GITHUB_TOKEN }}

    - name: Upload SBOM
      uses: actions/upload-artifact@v4
      with:
        name: sbom
        path: bom.json
EOF

    # Create tool manifest
    cat > .config/dotnet-tools.json << 'EOF'
{
  "version": 1,
  "isRoot": true,
  "tools": {
    "nbgv": {
      "version": "3.6.128",
      "commands": [
        "nbgv"
      ]
    }
  }
}
EOF
}

# Commit and push
commit_and_push() {
    local repo_name="$1"
    local repo_path="$DEFAULT_PATH/$repo_name"
    
    cd "$repo_path"
    
    log_info "Committing and pushing initial setup"
    
    git add .
    git commit -m "Initial CI/CD setup with Nerdbank.GitVersioning

- Add GitHub Actions workflows for CI/CD
- Configure Nerdbank.GitVersioning with SemVer 2.0
- Add security scanning and SBOM generation
- Setup branch protection and environments
- Add repository structure and configuration files"
    
    git push -u origin "$DEFAULT_BRANCH"
}

# Main execution
main() {
    log_info "Starting CI/CD repository setup for CyberDine Development"
    
    # Check dependencies
    check_dependencies
    
    # Ensure we're in the right directory
    mkdir -p "$DEFAULT_PATH"
    cd "$DEFAULT_PATH"
    
    # Repository descriptions
    declare -A DESCRIPTIONS=(
        ["smart-generators"]="Smart code generators for .NET development"
        ["enhanced-enums"]="Enhanced enum functionality for .NET"
        ["smart-switches"]="Intelligent switch expressions and pattern matching"
        ["smart-delegates"]="Smart delegate and event handling utilities"
        ["developer-kit"]="Comprehensive developer toolkit for .NET"
    )
    
    # Process each repository
    for repo in "${REPOSITORIES[@]}"; do
        log_info "=== Setting up $repo ==="
        
        # Create repository
        create_repository "$repo" "${DESCRIPTIONS[$repo]}"
        
        # Create project files
        create_project_files "$repo"
        
        # Setup environments and secrets
        setup_environments "$repo"
        setup_secrets "$repo"
        
        # Commit and push
        commit_and_push "$repo"
        
        # Setup branch protection (after first push)
        setup_branch_protection "$repo"
        
        log_info "✓ Completed setup for $repo"
        echo ""
    done
    
    log_info "=== Setup Summary ==="
    echo "Repositories created:"
    for repo in "${REPOSITORIES[@]}"; do
        echo "  - https://github.com/$ORG_NAME/$repo"
    done
    
    echo ""
    log_info "Next steps:"
    echo "1. Update NUGET_API_KEY secret for public package publishing"
    echo "2. Configure team access in GitHub organization settings"
    echo "3. Review and customize branch protection rules"
    echo "4. Run 'dotnet nbgv get-version' in any repo to see versioning"
    echo "5. Add your library code to the /src folder of each repository"
}

# Run main function
main "$@"