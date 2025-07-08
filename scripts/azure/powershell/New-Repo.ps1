# Azure DevOps Repository Setup Script
# Creates a new repository with CI/CD pipeline and Azure Artifacts integration

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
    [ValidateSet("private", "public")]
    [string]$Visibility,
    
    [Parameter(Mandatory = $false)]
    [string]$Project,
    
    [Parameter(Mandatory = $false)]
    [string]$Organization
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Function to read configuration
function Read-Configuration {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        Write-Host "Configuration file not found. Creating one..." -ForegroundColor Yellow
        New-Configuration -Path $Path
    }
    
    $config = Get-Content $Path | ConvertFrom-Json
    
    # Check if running in WSL
    $isWSL = $env:WSL_DISTRO_NAME -or (Test-Path "/proc/version" -ErrorAction SilentlyContinue)
    
    $script:repoPath = if ($isWSL -and $config.WSLPath) { 
        $config.WSLPath 
    } else { 
        $config.WindowsPath 
    }
    
    $script:azureOrg = $config.AzureOrganization
    $script:azureProject = $config.AzureProject
    $script:companyName = $config.CompanyName
    $script:defaultBranch = $config.DefaultBranch ?? "master"
    $script:defaultVisibility = $config.RepositoryVisibility ?? "private"
    $script:defaultLicense = $config.DefaultLicense ?? "MIT"
    $script:artifactFeed = $config.ArtifactFeed ?? "dotnet-packages"
}

# Function to create configuration
function New-Configuration {
    param([string]$Path)
    
    Write-Host "Setting up Azure DevOps configuration..." -ForegroundColor Cyan
    
    $azureOrg = Read-Host "Enter your Azure DevOps organization name"
    $azureProject = Read-Host "Enter your Azure DevOps project name"
    $companyName = Read-Host "Enter your company name"
    $artifactFeed = Read-Host "Enter default artifact feed name (default: dotnet-packages)"
    if ([string]::IsNullOrWhiteSpace($artifactFeed)) {
        $artifactFeed = "dotnet-packages"
    }
    
    # Determine paths based on environment
    $isWSL = $env:WSL_DISTRO_NAME -or (Test-Path "/proc/version" -ErrorAction SilentlyContinue)
    
    if ($isWSL) {
        Write-Host "WSL environment detected." -ForegroundColor Green
        $defaultPath = "/mnt/c/Source"
        $wslPath = Read-Host "Enter WSL repository path (default: $defaultPath)"
        if ([string]::IsNullOrWhiteSpace($wslPath)) {
            $wslPath = $defaultPath
        }
        
        # Convert WSL path to Windows path
        $windowsPath = $wslPath -replace '^/mnt/c', 'C:' -replace '/', '\'
    } else {
        $defaultPath = "C:\Source"
        $windowsPath = Read-Host "Enter repository path (default: $defaultPath)"
        if ([string]::IsNullOrWhiteSpace($windowsPath)) {
            $windowsPath = $defaultPath
        }
        $wslPath = $windowsPath -replace '^C:', '/mnt/c' -replace '\\', '/'
    }
    
    $config = @{
        AzureOrganization = $azureOrg
        AzureProject = $azureProject
        CompanyName = $companyName
        WindowsPath = $windowsPath
        WSLPath = $wslPath
        DefaultBranch = "master"
        RepositoryVisibility = "private"
        DefaultLicense = "MIT"
        ArtifactFeed = $artifactFeed
    }
    
    $config | ConvertTo-Json -Depth 10 | Set-Content $Path
    Write-Host "Configuration saved to $Path" -ForegroundColor Green
}

# Function to check Azure CLI
function Test-AzureCLI {
    try {
        $null = az --version
    } catch {
        throw "Azure CLI is not installed. Please install it from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }
    
    # Check if logged in
    try {
        $null = az account show 2>$null
    } catch {
        Write-Host "Not logged in to Azure CLI. Please log in..." -ForegroundColor Yellow
        az login
    }
    
    # Check if Azure DevOps extension is installed
    $extensions = az extension list --query "[?name=='azure-devops'].name" -o tsv
    if (-not $extensions) {
        Write-Host "Installing Azure DevOps extension..." -ForegroundColor Yellow
        az extension add --name azure-devops
    }
}

# Function to create repository
function New-AzureDevOpsRepository {
    param(
        [string]$Name,
        [string]$Visibility
    )
    
    Write-Host "Creating Azure DevOps repository: $Name" -ForegroundColor Cyan
    
    # Set defaults
    az devops configure --defaults organization="https://dev.azure.com/$azureOrg" project="$azureProject"
    
    # Create repository
    $repoInfo = az repos create --name $Name --detect false -o json | ConvertFrom-Json
    $script:repoId = $repoInfo.id
    
    Write-Host "Repository created with ID: $repoId" -ForegroundColor Green
    
    # Initialize with README
    @"
# $Name

## Overview

This repository contains...

## Getting Started

### Prerequisites

- .NET 9.0 SDK or later
- Azure CLI (for deployment)

### Building

``````bash
dotnet build
``````

### Testing

``````bash
dotnet test
``````

### Contributing

Please read our contributing guidelines before submitting PRs.
"@ | Set-Content README.md
    
    git add README.md
    git commit -m "Initial commit"
    
    # Set remote
    git remote add origin $repoInfo.remoteUrl
}

# Function to setup artifact feed
function Set-ArtifactFeed {
    param([string]$FeedName)
    
    Write-Host "Checking Azure Artifacts feed: $FeedName" -ForegroundColor Cyan
    
    # Check if feed exists
    try {
        $null = az artifacts feed show --name $FeedName --org "https://dev.azure.com/$azureOrg" 2>$null
    } catch {
        Write-Host "Creating Azure Artifacts feed: $FeedName" -ForegroundColor Yellow
        az artifacts feed create `
            --name $FeedName `
            --org "https://dev.azure.com/$azureOrg" `
            --description "NuGet packages for .NET projects"
    }
    
    # Set feed permissions (organization-scoped)
    Write-Host "Setting feed permissions..." -ForegroundColor Yellow
    az artifacts feed permission update `
        --feed $FeedName `
        --org "https://dev.azure.com/$azureOrg" `
        --role contributor `
        --identity "Project Collection Build Service ($azureOrg)"
}

# Function to create nuget.config
function New-NuGetConfig {
    param([string]$FeedName)
    
    @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="$FeedName" value="https://pkgs.dev.azure.com/$azureOrg/$azureProject/_packaging/$FeedName/nuget/v3/index.json" />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
  <packageSourceMapping>
    <packageSource key="$FeedName">
      <package pattern="$companyName.*" />
    </packageSource>
    <packageSource key="nuget.org">
      <package pattern="*" />
    </packageSource>
  </packageSourceMapping>
</configuration>
"@ | Set-Content nuget.config
}

# Function to create pipeline
function New-Pipeline {
    param([string]$RepoName)
    
    Write-Host "Setting up Azure Pipelines..." -ForegroundColor Cyan
    
    # Get the root directory of the repository
    $repoRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    $pipelineDir = Join-Path $repoRoot "pipelines"
    
    # Copy pipeline files
    New-Item -ItemType Directory -Force -Path ".azuredevops" | Out-Null
    Copy-Item "$pipelineDir\dotnet-ci-cd.yml" "azure-pipelines.yml"
    Copy-Item "$pipelineDir\security.yml" ".azuredevops\security-pipeline.yml"
    
    # Create main pipeline
    $pipelineInfo = az pipelines create `
        --name "$RepoName-CI-CD" `
        --repository $RepoName `
        --repository-type tfsgit `
        --branch $defaultBranch `
        --yml-path "azure-pipelines.yml" `
        --skip-first-run true `
        -o json | ConvertFrom-Json
    
    $script:pipelineId = $pipelineInfo.id
    
    # Create security pipeline
    az pipelines create `
        --name "$RepoName-Security" `
        --repository $RepoName `
        --repository-type tfsgit `
        --branch $defaultBranch `
        --yml-path ".azuredevops/security-pipeline.yml" `
        --skip-first-run true
    
    Write-Host "Pipelines created successfully" -ForegroundColor Green
}

# Function to setup branch policies
function Set-BranchPolicies {
    param([string]$RepoId)
    
    Write-Host "Setting up branch policies for $defaultBranch..." -ForegroundColor Cyan
    
    # Create build validation policy
    $buildPolicy = @{
        isEnabled = $true
        isBlocking = $true
        settings = @{
            buildDefinitionId = $pipelineId
            displayName = "PR Build Validation"
            queueOnSourceUpdateOnly = $false
            validDuration = 720
            scope = @(@{
                repositoryId = $RepoId
                refName = "refs/heads/$defaultBranch"
                matchKind = "Exact"
            })
        }
    } | ConvertTo-Json -Depth 10
    
    # Note: Branch policies require REST API calls
    Write-Host "Branch policies configuration created. Manual setup may be required in Azure DevOps portal." -ForegroundColor Yellow
}

# Function to create variable groups
function New-VariableGroups {
    Write-Host "Creating variable groups..." -ForegroundColor Cyan
    
    # Development secrets
    az pipelines variable-group create `
        --name "development-secrets" `
        --variables ASPNETCORE_ENVIRONMENT=Development `
        --authorize true `
        --description "Development environment secrets"
    
    # Staging secrets
    az pipelines variable-group create `
        --name "staging-secrets" `
        --variables ASPNETCORE_ENVIRONMENT=Staging `
        --authorize true `
        --description "Staging environment secrets"
    
    # Production secrets
    az pipelines variable-group create `
        --name "production-secrets" `
        --variables ASPNETCORE_ENVIRONMENT=Production `
        --authorize true `
        --description "Production environment secrets"
    
    Write-Host "Variable groups created successfully" -ForegroundColor Green
}

# Function to setup project structure
function Set-ProjectStructure {
    param(
        [string]$Name,
        [string]$License
    )
    
    Write-Host "Setting up .NET project structure..." -ForegroundColor Cyan
    
    # Create directories
    New-Item -ItemType Directory -Force -Path "src", "tests", "docs", ".config", ".azuredevops" | Out-Null
    
    # Create solution
    dotnet new sln -n $Name
    
    # Create main project
    Push-Location src
    dotnet new classlib -n $Name -f net9.0
    Pop-Location
    dotnet sln add "src\$Name\$Name.csproj"
    
    # Create test project
    Push-Location tests
    dotnet new xunit -n "$Name.Tests" -f net9.0
    Pop-Location
    dotnet sln add "tests\$Name.Tests\$Name.Tests.csproj"
    
    # Add project reference
    dotnet add "tests\$Name.Tests\$Name.Tests.csproj" reference "src\$Name\$Name.csproj"
    
    # Create .gitignore
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/github/gitignore/main/VisualStudio.gitignore" -OutFile ".gitignore"
    Add-Content ".gitignore" "`n# Azure DevOps`n.azuredevops/local/`n*.user"
    
    # Create license
    New-LicenseFile -Type $License
    
    # Create version.json for nbgv
    New-VersionJson
    
    # Install and configure nbgv
    dotnet tool install -g nbgv 2>$null
    nbgv install
}

# Function to create license file
function New-LicenseFile {
    param([string]$Type)
    
    switch ($Type) {
        "MIT" {
            @"
MIT License

Copyright (c) $(Get-Date -Format yyyy) $companyName

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"@ | Set-Content LICENSE
        }
        "Apache-2.0" {
            Invoke-WebRequest -Uri "https://www.apache.org/licenses/LICENSE-2.0.txt" -OutFile LICENSE
        }
    }
}

# Function to create version.json
function New-VersionJson {
    @"
{
  "`$schema": "https://raw.githubusercontent.com/dotnet/Nerdbank.GitVersioning/master/src/NerdBank.GitVersioning/version.schema.json",
  "version": "1.0-alpha",
  "assemblyVersion": {
    "precision": "major.minor"
  },
  "publicReleaseRefSpec": [
    "^refs/heads/$defaultBranch`$",
    "^refs/heads/release/.*`$"
  ],
  "nugetPackageVersion": {
    "semVer": 2
  },
  "cloudBuild": {
    "buildNumber": {
      "enabled": true
    },
    "setVersionVariables": true,
    "setAllVariables": true
  },
  "release": {
    "firstUnstableTag": "alpha",
    "branchName": "release/v{version}",
    "tagFormat": "v{version}",
    "versionIncrement": "minor"
  }
}
"@ | Set-Content version.json
}

# Main execution
try {
    # Read configuration
    Read-Configuration -Path $ConfigPath
    
    # Use provided values or defaults
    if (-not $License) { $License = $defaultLicense }
    if (-not $Visibility) { $Visibility = $defaultVisibility }
    if (-not $Project) { $Project = $azureProject }
    if (-not $Organization) { $Organization = $azureOrg }
    
    # Update variables if overridden
    $azureProject = $Project
    $azureOrg = $Organization
    
    # Check Azure CLI
    Test-AzureCLI
    
    # Create repository directory
    $repoDir = Join-Path $repoPath $RepositoryName
    if (Test-Path $repoDir) {
        throw "Directory $repoDir already exists"
    }
    
    New-Item -ItemType Directory -Force -Path $repoDir | Out-Null
    Set-Location $repoDir
    
    # Initialize git
    git init -b $defaultBranch
    
    # Setup artifact feed
    Set-ArtifactFeed -FeedName $artifactFeed
    
    # Create nuget.config
    New-NuGetConfig -FeedName $artifactFeed
    
    # Setup project structure
    Set-ProjectStructure -Name $RepositoryName -License $License
    
    # Create repository in Azure DevOps
    New-AzureDevOpsRepository -Name $RepositoryName -Visibility $Visibility
    
    # Create variable groups
    New-VariableGroups
    
    # Create pipeline
    New-Pipeline -RepoName $RepositoryName
    
    # Setup branch policies
    Set-BranchPolicies -RepoId $repoId
    
    # Commit and push
    git add .
    git commit -m "Initial project setup with Azure DevOps CI/CD"
    git push -u origin $defaultBranch
    
    # Create develop branch
    git checkout -b develop
    git push -u origin develop
    
    # Switch back to default branch
    git checkout $defaultBranch
    
    Write-Host "`n✅ Repository setup complete!" -ForegroundColor Green
    Write-Host "📁 Location: $repoDir" -ForegroundColor Cyan
    Write-Host "🔗 Azure DevOps: https://dev.azure.com/$azureOrg/$azureProject/_git/$RepositoryName" -ForegroundColor Cyan
    Write-Host "📦 Artifact Feed: https://dev.azure.com/$azureOrg/$azureProject/_artifacts/feed/$artifactFeed" -ForegroundColor Cyan
    Write-Host "`nNext steps:" -ForegroundColor Yellow
    Write-Host "1. Configure Key Vault secrets in variable groups" -ForegroundColor White
    Write-Host "2. Set up service connections if needed" -ForegroundColor White
    Write-Host "3. Run the pipeline to verify setup" -ForegroundColor White
    
} catch {
    Write-Error "Error: $_"
    exit 1
}