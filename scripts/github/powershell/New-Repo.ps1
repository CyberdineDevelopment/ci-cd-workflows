# New-Repo.ps1 - Create a single new repository with CI/CD setup

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$RepositoryName,
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "..\..\..\config.json",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Apache-2.0", "MIT")]
    [string]$License,
    
    [Parameter(Mandatory = $false)]
    [switch]$Help
)

# Logging functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] ${Message}" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] ${Message}" -ForegroundColor Red
}

# Show help
function Show-Help {
    Write-Host @"
New-Repo.ps1 - Create a single new repository with CI/CD setup

USAGE:
    New-Repo.ps1 REPOSITORY_NAME [OPTIONS]

ARGUMENTS:
    RepositoryName      Name of the repository to create

OPTIONS:
    -ConfigPath PATH    Path to configuration file (default: .\config.json)
    -License LICENSE    License to use (Apache-2.0 or MIT, default: from config)
    -Help               Show this help message

EXAMPLES:
    # Create a new repository
    New-Repo.ps1 my-new-library
    
    # Use custom config
    New-Repo.ps1 my-library -ConfigPath "..\config.json"
    
    # Override license
    New-Repo.ps1 my-library -License MIT

"@
}

# Load or create configuration
function Get-Configuration {
    param([string]$ConfigFilePath)
    
    if (-not (Test-Path $ConfigFilePath)) {
        Write-Info "Configuration file not found. Creating configuration..."
        
        # Ensure config directory exists
        $configDir = Split-Path $ConfigFilePath -Parent
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        
        # Ask configuration questions
        Write-Host ""
        Write-Host "=== CI/CD Configuration Setup ===" -ForegroundColor Cyan
        Write-Host ""
        
        do { $githubOrg = Read-Host "GitHub Organization name" } while ([string]::IsNullOrWhiteSpace($githubOrg))
        do { $companyName = Read-Host "Company name" } while ([string]::IsNullOrWhiteSpace($companyName))
        
        # WSL path
        $wslDefault = "/home/$env:USERNAME/projects"
        $wslInput = Read-Host "WSL path for repositories ($wslDefault)"
        $wslPath = if ([string]::IsNullOrWhiteSpace($wslInput)) { $wslDefault } else { $wslInput }
        
        # Windows path
        $windowsDefault = "D:\fractaldataworks"
        $windowsInput = Read-Host "Windows path for repositories ($windowsDefault)"
        $windowsPath = if ([string]::IsNullOrWhiteSpace($windowsInput)) { $windowsDefault } else { $windowsInput }
        
        Write-Host ""
        Write-Host "Repository visibility options:"
        Write-Host "  1) Private (recommended for internal projects)"
        Write-Host "  2) Public (for open source projects)"
        $visChoice = Read-Host "Select repository visibility (1-2)"
        $repoVisibility = if ($visChoice -eq "2") { "public" } else { "private" }
        
        $branchInput = Read-Host "Default branch name (master)"
        $defaultBranch = if ([string]::IsNullOrWhiteSpace($branchInput)) { "master" } else { $branchInput }
        
        Write-Host ""
        Write-Host "Default license options:"
        Write-Host "  1) Apache-2.0 (recommended for business)"
        Write-Host "  2) MIT (simple permissive)"
        $licenseChoice = Read-Host "Select default license (1-2)"
        $defaultLicense = if ($licenseChoice -eq "2") { "MIT" } else { "Apache-2.0" }
        
        # Create configuration
        $config = @{
            GitHubOrganization = $githubOrg
            CompanyName = $companyName
            WSLPath = $wslPath
            WindowsPath = $windowsPath
            DefaultBranch = $defaultBranch
            RepositoryVisibility = $repoVisibility
            DefaultLicense = $defaultLicense
            ScriptPath = Split-Path $PSScriptRoot -Parent
            LastUpdated = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        $config | ConvertTo-Json -Depth 3 | Out-File -FilePath $ConfigFilePath -Encoding UTF8
        Write-Info "Configuration saved to: $ConfigFilePath"
    }
    
    Write-Info "Loading configuration from: $ConfigFilePath"
    
    $config = Get-Content $ConfigFilePath -Raw | ConvertFrom-Json
    
    # Convert to hashtable for easier manipulation
    $configHash = @{}
    $config.PSObject.Properties | ForEach-Object { $configHash[$_.Name] = $_.Value }
    
    # Use Windows path for PowerShell, or fallback to old config format
    if ($configHash.WindowsPath) {
        $configHash.DefaultPath = $configHash.WindowsPath
    } elseif ($configHash.DefaultPath -match "^/") {
        # Old config format with Unix path - prompt for Windows path
        Write-Host ""
        Write-Host "⚠️  Your configuration uses the old format. Please provide a Windows path." -ForegroundColor Yellow
        $windowsPath = Read-Host "Windows path for repositories (e.g., D:\fractaldataworks)"
        if ($windowsPath) {
            $configHash.DefaultPath = $windowsPath
            Write-Info "Using Windows path: $windowsPath"
            Write-Info "Note: Run the script again to save the new dual-path configuration format"
        }
    }
    
    # Validate required values
    if ([string]::IsNullOrWhiteSpace($configHash.GitHubOrganization) -or 
        [string]::IsNullOrWhiteSpace($configHash.CompanyName) -or 
        [string]::IsNullOrWhiteSpace($configHash.DefaultPath)) {
        Write-Error "Invalid configuration. Required values missing."
        Write-Info "Please delete the config file and run the script again to recreate it."
        exit 1
    }
    
    return $configHash
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

# Create repository
function New-GitHubRepository {
    param(
        [hashtable]$Config,
        [string]$RepoName
    )
    
    Write-Info "Creating repository: $($Config.GitHubOrganization)/${RepoName}"
    
    Set-Location $Config.DefaultPath
    
    # Create repository
    $visibilityFlag = if ($Config.RepositoryVisibility -eq "public") { "--public" } else { "--private" }
    $repoLicense = if ($License) { $License } else { $Config.DefaultLicense }
    $description = "${RepoName} library for .NET development"
    
    try {
        gh repo create "$($Config.GitHubOrganization)/${RepoName}" `
            $visibilityFlag `
            --description $description `
            --gitignore "VisualStudio" `
            --license $repoLicense `
            --confirm
    } catch {
        Write-Error "Failed to create repository. It may already exist."
        exit 1
    }
    
    # Clone repository
    gh repo clone "$($Config.GitHubOrganization)/${RepoName}"
    Set-Location $RepoName
    
    # Change default branch if needed
    if ($Config.DefaultBranch -ne "main") {
        git checkout -b $Config.DefaultBranch
        git push -u origin $Config.DefaultBranch
        gh repo edit "$($Config.GitHubOrganization)/${RepoName}" --default-branch $Config.DefaultBranch
        git push origin --delete main 2>$null
    }
}

# Create standard branches
function New-Branches {
    param(
        [hashtable]$Config,
        [string]$RepoName
    )
    
    Write-Info "Setting up standard branches..."
    
    # Ensure we're on master
    git checkout $Config.DefaultBranch
    
    # Create develop branch if it doesn't exist
    $remoteBranches = git branch -r
    if ($remoteBranches -notcontains "  origin/develop") {
        Write-Info "Creating develop branch..."
        git checkout -b develop
        git push -u origin develop
        git checkout $Config.DefaultBranch
    } else {
        Write-Info "Develop branch already exists"
    }
}

# Setup repository files
function Set-RepositoryFiles {
    param(
        [hashtable]$Config,
        [string]$RepoName,
        [string]$RepoLicense
    )
    
    Write-Info "Setting up CI/CD files for ${RepoName}"
    
    # Create directory structure
    New-Item -ItemType Directory -Force -Path ".github\workflows", "src", "tests", "docs", ".config" | Out-Null
    
    # Copy workflow templates from the workflows directory
    $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    $workflowDir = Join-Path $repoRoot "workflows"
    if (Test-Path $workflowDir) {
        Copy-Item "$workflowDir\dotnet-ci-cd.yml" ".github\workflows\" -ErrorAction SilentlyContinue
        Copy-Item "$workflowDir\security.yml" ".github\workflows\" -ErrorAction SilentlyContinue
        Write-Info "Copied CI/CD workflows from $workflowDir"
    } else {
        Write-Error "Workflow directory not found at: $workflowDir"
    }
    
    # Create global.json
    @"
{
  "sdk": {
    "version": "9.0",
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
    <!-- Disable warnings as errors on develop branch for faster iteration -->
    <TreatWarningsAsErrors Condition="'$(GITHUB_REF_NAME)' == 'develop'">false</TreatWarningsAsErrors>
    <!-- Enable warnings as errors for master/release branches -->
    <TreatWarningsAsErrors Condition="'$(GITHUB_REF_NAME)' == 'master' or '$(GITHUB_REF_NAME)' == 'main' or $(GITHUB_REF_NAME.StartsWith('release/'))">true</TreatWarningsAsErrors>
    <!-- Default to warnings as errors for local builds -->
    <TreatWarningsAsErrors Condition="'$(GITHUB_REF_NAME)' == ''">true</TreatWarningsAsErrors>
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
    <NoWarn>$(NoWarn);CS1591</NoWarn>
    <!-- Suppress analyzer warnings on develop branch for faster iteration -->
    <NoWarn Condition="'$(GITHUB_REF_NAME)' == 'develop'">$(NoWarn);CA1062;CA1034;CA1310;CA1054;CA1031;CA2227;CA1024;CA1860;CS1591;CS8618;CS8603;CS8625</NoWarn>
    <!-- Disable nullable warnings on develop branch for faster development -->
    <Nullable Condition="'$(GITHUB_REF_NAME)' == 'develop'">disable</Nullable>
    
    <!-- Package properties -->
    <Authors>$($Config.CompanyName)</Authors>
    <Company>$($Config.CompanyName)</Company>
    <Copyright>Copyright (c) $($Config.CompanyName) $([System.DateTime]::Now.Year)</Copyright>
    <PackageLicenseExpression>$RepoLicense</PackageLicenseExpression>
    <RepositoryUrl>https://github.com/$($Config.GitHubOrganization)/$(MSBuildProjectName)</RepositoryUrl>
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

    # Create version.json
    @'
{
  "$schema": "https://raw.githubusercontent.com/dotnet/Nerdbank.GitVersioning/master/src/NerdBank.GitVersioning/version.schema.json",
  "version": "0.1-alpha",
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
    "firstUnstableTag": "rc"
  },
  "pathFilters": [
    "./src",
    "./tests",
    "!/docs"
  ],
  "branches": {
    "master": {
      "tag": ""
    },
    "develop": {
      "tag": "alpha"
    },
    "release/.*": {
      "tag": "rc"
    },
    "feature/.*": {
      "tag": "feature-{BranchName}"
    }
  },
  "inherit": false
}
'@ | Out-File -FilePath "version.json" -Encoding utf8

    # Create README
    @"
# ${RepoName}

Part of the $($Config.CompanyName) toolkit.

## Build Status

[![Master Build](https://github.com/$($Config.GitHubOrganization)/${RepoName}/actions/workflows/dotnet-ci-cd.yml/badge.svg?branch=master)](https://github.com/$($Config.GitHubOrganization)/${RepoName}/actions/workflows/dotnet-ci-cd.yml)
[![Develop Build](https://github.com/$($Config.GitHubOrganization)/${RepoName}/actions/workflows/dotnet-ci-cd.yml/badge.svg?branch=develop)](https://github.com/$($Config.GitHubOrganization)/${RepoName}/actions/workflows/dotnet-ci-cd.yml)

## Release Status

![GitHub release (latest by date)](https://img.shields.io/github/v/release/$($Config.GitHubOrganization)/${RepoName})
![GitHub release (latest by date including pre-releases)](https://img.shields.io/github/v/release/$($Config.GitHubOrganization)/${RepoName}?include_prereleases&label=pre-release)

## Package Status

![Nuget](https://img.shields.io/nuget/v/$($Config.CompanyName).${RepoName})
![GitHub Packages](https://img.shields.io/badge/github%20packages-available-blue)

## Installation

``````bash
dotnet add package FractalDataWorks.${RepoName}
``````

## Development

This repository contains library packages for .NET development. To use these packages:

1. Reference the package in your project
2. Follow the documentation in the ``/docs`` folder
3. See examples in the ``/samples`` folder (if available)

## License

MIT
"@ | Out-File -FilePath "README.md" -Encoding utf8

    # Create nuget.config in home directory for internal package dependencies
    $nugetDir = "$env:APPDATA\NuGet"
    if (!(Test-Path $nugetDir)) { New-Item -ItemType Directory -Path $nugetDir -Force | Out-Null }
    @'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
    <add key="github" value="https://nuget.pkg.github.com/$($Config.GitHubOrganization)/index.json" />
  </packageSources>
  <packageSourceMapping>
    <packageSource key="nuget.org">
      <package pattern="*" />
    </packageSource>
    <packageSource key="github">
      <package pattern="$($Config.CompanyName).*" />
    </packageSource>
  </packageSourceMapping>
</configuration>
'@ | Out-File -FilePath "$nugetDir\NuGet.Config" -Encoding utf8

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

# Configure repository settings
function Set-RepositoryConfiguration {
    param(
        [hashtable]$Config,
        [string]$RepoName
    )
    
    Write-Info "Configuring repository settings"
    
    gh repo edit "$($Config.GitHubOrganization)/${RepoName}" `
        --enable-issues `
        --enable-wiki `
        --delete-branch-on-merge `
        --add-topic "dotnet,csharp,nuget" 2>$null
}

# Commit and push
function Invoke-CommitAndPush {
    param(
        [hashtable]$Config,
        [string]$RepoName
    )
    
    Write-Info "Committing and pushing initial setup"
    
    git add .
    git commit -m "Initial CI/CD setup with Nerdbank.GitVersioning

- Add GitHub Actions workflows for CI/CD
- Configure Nerdbank.GitVersioning with SemVer 2.0
- Add security scanning and SBOM generation
- Add repository structure and configuration files"
    
    git push -u origin $Config.DefaultBranch
}

# Main execution
function Main {
    if ($Help) {
        Show-Help
        return
    }
    
    Write-Info "Creating new repository: ${RepositoryName}"
    
    Test-Dependencies
    $config = Get-Configuration -ConfigFilePath $ConfigPath
    
    Write-Info "Using configuration:"
    Write-Host "  GitHub Organization: $($config.GitHubOrganization)"
    Write-Host "  Company Name: $($config.CompanyName)"
    Write-Host "  Default Path: $($config.DefaultPath)"
    Write-Host "  Repository Visibility: $($config.RepositoryVisibility)"
    Write-Host "  Default Branch: $($config.DefaultBranch)"
    Write-Host ""
    
    New-GitHubRepository -Config $config -RepoName $RepositoryName
    New-Branches -Config $config -RepoName $RepositoryName
    $repoLicense = if ($License) { $License } else { $config.DefaultLicense }
    Set-RepositoryFiles -Config $config -RepoName $RepositoryName -RepoLicense $repoLicense
    Set-RepositoryConfiguration -Config $config -RepoName $RepositoryName
    Invoke-CommitAndPush -Config $config -RepoName $RepositoryName
    
    Write-Info "✓ Repository ${RepositoryName} created successfully!"
    Write-Host ""
    Write-Host "Repository URL: https://github.com/$($config.GitHubOrganization)/${RepositoryName}"
    Write-Host "Local path: $($config.DefaultPath)\${RepositoryName}"
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "1. Add your library code to the /src folder"
    Write-Host "2. Add tests to the /tests folder"
    Write-Host "3. Push your first commit to trigger CI/CD"
}

Main