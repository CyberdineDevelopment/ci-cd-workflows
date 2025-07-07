# Setup-CICDRepos.ps1 - Complete CI/CD setup for multiple .NET repositories
# Organization: cyberdinedevelopment

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Organization = "cyberdinedevelopment",
    
    [Parameter(Mandatory = $false)]
    [string]$DefaultPath = "D:\fractaldataworks",
    
    [Parameter(Mandatory = $false)]
    [string]$DefaultBranch = "master",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipBranchProtection,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipSecrets
)

# Configuration
$DotNetVersion = "9.0"
$NbgvVersion = "3.6.*"

# Repositories to create
$Repositories = @(
    "smart-generators",
    "enhanced-enums", 
    "smart-switches",
    "smart-delegates",
    "developer-kit"
)

# Repository descriptions
$Descriptions = @{
    "smart-generators" = "Smart code generators for .NET development"
    "enhanced-enums" = "Enhanced enum functionality for .NET"
    "smart-switches" = "Intelligent switch expressions and pattern matching"
    "smart-delegates" = "Smart delegate and event handling utilities"
    "developer-kit" = "Comprehensive developer toolkit for .NET"
}

# Logging functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] ${Message}" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] ${Message}" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] ${Message}" -ForegroundColor Red
}

# Check dependencies
function Test-Dependencies {
    Write-Info "Checking dependencies..."
    
    $deps = @("gh", "git", "dotnet")
    foreach ($dep in $deps) {
        if (-not (Get-Command $dep -ErrorAction SilentlyContinue)) {
            Write-Error "${dep} is not installed"
            exit 1
        }
    }
    
    # Check GitHub authentication
    try {
        gh auth status 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Not authenticated with GitHub. Run 'gh auth login' first."
            exit 1
        }
    } catch {
        Write-Error "GitHub CLI error. Ensure gh is properly installed."
        exit 1
    }
    
    Write-Info "All dependencies satisfied"
}

# Create and configure repository
function New-GitHubRepository {
    param(
        [string]$RepoName,
        [string]$Description
    )
    
    Write-Info "Creating repository: ${Organization}/${RepoName}"
    
    # Create repository - Note: gh doesn't support --default-branch flag
    $currentLocation = Get-Location
    Set-Location $DefaultPath
    
    try {
        # Create without clone first
        gh repo create "${Organization}/${RepoName}" `
            --private `
            --description "${Description}" `
            --gitignore "VisualStudio" `
            --license "MIT" `
            --confirm
        
        # Clone the repository
        gh repo clone "${Organization}/${RepoName}"
        
        # Change default branch if needed
        if ($DefaultBranch -ne "main") {
            Set-Location (Join-Path $DefaultPath $RepoName)
            git checkout -b $DefaultBranch
            git push -u origin $DefaultBranch
            
            # Set default branch on GitHub
            gh repo edit "${Organization}/${RepoName}" --default-branch $DefaultBranch
            
            # Delete main branch
            git push origin --delete main 2>$null
        }
    } catch {
        Write-Warn "Repository may already exist, attempting to clone..."
        gh repo clone "${Organization}/${RepoName}"
    }
    
    Set-Location (Join-Path $DefaultPath $RepoName)
    
    # Configure repository settings
    Write-Info "Configuring repository settings..."
    gh repo edit "${Organization}/${RepoName}" `
        --enable-issues `
        --enable-wiki `
        --enable-discussions `
        --enable-projects `
        --enable-auto-merge `
        --enable-squash-merge `
        --enable-rebase-merge `
        --delete-branch-on-merge `
        --add-topic "dotnet,csharp,nuget" 2>$null
}

# Setup branch protection
function Set-BranchProtection {
    param([string]$RepoName)
    
    if ($SkipBranchProtection) {
        Write-Warn "Skipping branch protection setup"
        return
    }
    
    Write-Info "Setting up branch protection for ${DefaultBranch} branch"
    
    # Wait for branch to be available
    Start-Sleep -Seconds 2
    
    $protection = @{
        required_status_checks = @{
            strict = $true
            contexts = @("build", "test", "security")
        }
        required_pull_request_reviews = @{
            required_approving_review_count = 1
            dismiss_stale_reviews = $true
            require_code_owner_reviews = $true
        }
        enforce_admins = $false
        required_linear_history = $true
        allow_force_pushes = $false
        allow_deletions = $false
        required_conversation_resolution = $true
        lock_branch = $false
        allow_fork_syncing = $true
    } | ConvertTo-Json -Depth 10 -Compress
    
    $protection | gh api --method PUT "repos/${Organization}/${RepoName}/branches/${DefaultBranch}/protection" --input - 2>$null
}

# Setup GitHub environments
function Set-GitHubEnvironments {
    param([string]$RepoName)
    
    Write-Info "Setting up deployment environments"
    
    # Create staging environment
    gh api --method PUT "repos/${Organization}/${RepoName}/environments/staging" `
        --field "wait_timer=0" `
        --field "deployment_branch_policy=null" 2>$null
    
    # Create production environment with protection
    gh api --method PUT "repos/${Organization}/${RepoName}/environments/production" `
        --field "wait_timer=30" `
        --field "deployment_branch_policy[protected_branches]=true" `
        --field "deployment_branch_policy[custom_branch_policies]=false" 2>$null
}

# Setup secrets
function Set-RepositorySecrets {
    param([string]$RepoName)
    
    if ($SkipSecrets) {
        Write-Warn "Skipping secrets setup"
        return
    }
    
    Write-Info "Setting up repository secrets"
    
    # Repository-level secrets
    "dummy-key-replace-in-production" | gh secret set NUGET_API_KEY --repo "${Organization}/${RepoName}" 2>$null
    
    # Environment-specific secrets
    "staging-connection-string" | gh secret set DATABASE_URL --repo "${Organization}/${RepoName}" --env staging 2>$null
    "production-connection-string" | gh secret set DATABASE_URL --repo "${Organization}/${RepoName}" --env production 2>$null
}

# Create project files
function New-ProjectFiles {
    param(
        [string]$RepoName,
        [string]$RepoPath
    )
    
    Set-Location $RepoPath
    
    # Create directory structure
    New-Item -ItemType Directory -Force -Path ".github\workflows" | Out-Null
    New-Item -ItemType Directory -Force -Path "src" | Out-Null
    New-Item -ItemType Directory -Force -Path "tests" | Out-Null
    New-Item -ItemType Directory -Force -Path "docs" | Out-Null
    New-Item -ItemType Directory -Force -Path ".config" | Out-Null
    
    # Create .gitignore
    @'
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
'@ | Out-File -FilePath ".gitignore" -Encoding utf8

    # Create global.json
    @"
{
  "sdk": {
    "version": "${DotNetVersion}",
    "rollForward": "latestFeature",
    "allowPrerelease": false
  }
}
"@ | Out-File -FilePath "global.json" -Encoding utf8

    # Create Directory.Build.props
    @'
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
'@ | Out-File -FilePath "Directory.Build.props" -Encoding utf8

    # Create .editorconfig
    @'
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
'@ | Out-File -FilePath ".editorconfig" -Encoding utf8

    # Create nuget.config
    @'
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
'@ | Out-File -FilePath "nuget.config" -Encoding utf8

    # Create version.json for Nerdbank.GitVersioning
    @'
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
'@ | Out-File -FilePath "version.json" -Encoding utf8

    # Create SECURITY.md
    @'
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
'@ | Out-File -FilePath "SECURITY.md" -Encoding utf8

    # Create README.md
    @"
# ${RepoName}

Part of the CyberDine Development toolkit.

## Build Status

[![.NET CI/CD Pipeline](https://github.com/${Organization}/${RepoName}/actions/workflows/dotnet-ci-cd.yml/badge.svg)](https://github.com/${Organization}/${RepoName}/actions/workflows/dotnet-ci-cd.yml)

## Installation

``````bash
dotnet add package CyberDine.${RepoName}
``````

## Development

This repository contains library packages for .NET development. To use these packages:

1. Reference the package in your project
2. Follow the documentation in the `/docs` folder
3. See examples in the `/samples` folder (if available)

## License

MIT
"@ | Out-File -FilePath "README.md" -Encoding utf8

    # Create .github/dependabot.yml
    @'
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
'@ | Out-File -FilePath ".github\dependabot.yml" -Encoding utf8

    # Create .github/CODEOWNERS
    @'
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
'@ | Out-File -FilePath ".github\CODEOWNERS" -Encoding utf8

    # Create main CI/CD workflow
    @'
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
'@ | Out-File -FilePath ".github\workflows\dotnet-ci-cd.yml" -Encoding utf8

    # Create security workflow
    @'
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
'@ | Out-File -FilePath ".github\workflows\security.yml" -Encoding utf8

    # Create tool manifest
    @'
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
'@ | Out-File -FilePath ".config\dotnet-tools.json" -Encoding utf8
}

# Commit and push
function Invoke-CommitAndPush {
    param(
        [string]$RepoName,
        [string]$RepoPath
    )
    
    Set-Location $RepoPath
    
    Write-Info "Committing and pushing initial setup"
    
    git add .
    git commit -m "Initial CI/CD setup with Nerdbank.GitVersioning

- Add GitHub Actions workflows for CI/CD
- Configure Nerdbank.GitVersioning with SemVer 2.0
- Add security scanning and SBOM generation
- Setup branch protection and environments
- Add repository structure and configuration files"
    
    git push -u origin $DefaultBranch
}

# Main execution
function Main {
    Write-Info "Starting CI/CD repository setup for CyberDine Development"
    
    # Check dependencies
    Test-Dependencies
    
    # Ensure we're in the right directory
    New-Item -ItemType Directory -Force -Path $DefaultPath | Out-Null
    Set-Location $DefaultPath
    
    # Process each repository
    foreach ($repo in $Repositories) {
        Write-Info "=== Setting up ${repo} ==="
        
        # Create repository
        New-GitHubRepository -RepoName $repo -Description $Descriptions[$repo]
        
        # Create project files
        New-ProjectFiles -RepoName $repo -RepoPath (Join-Path $DefaultPath $repo)
        
        # Setup environments and secrets
        Set-GitHubEnvironments -RepoName $repo
        Set-RepositorySecrets -RepoName $repo
        
        # Commit and push
        Invoke-CommitAndPush -RepoName $repo -RepoPath (Join-Path $DefaultPath $repo)
        
        # Setup branch protection (after first push)
        Set-BranchProtection -RepoName $repo
        
        Write-Info "✓ Completed setup for ${repo}"
        Write-Host ""
    }
    
    Write-Info "=== Setup Summary ==="
    Write-Host "Repositories created:"
    foreach ($repo in $Repositories) {
        Write-Host "  - https://github.com/${Organization}/${repo}"
    }
    
    Write-Host ""
    Write-Info "Next steps:"
    Write-Host "1. Update NUGET_API_KEY secret for public package publishing"
    Write-Host "2. Configure team access in GitHub organization settings"
    Write-Host "3. Review and customize branch protection rules"
    Write-Host "4. Run 'dotnet nbgv get-version' in any repo to see versioning"
    Write-Host "5. Add your library code to the /src folder of each repository"
}

# Run main function
Main