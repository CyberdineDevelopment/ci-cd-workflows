#!/bin/bash

# Azure DevOps Repository Setup Script
# Creates a new repository with CI/CD pipeline and Azure Artifacts integration

set -euo pipefail

# Configuration file path (three levels up from scripts/azure/bash)
CONFIG_FILE="../../../config.json"

# Function to display usage
usage() {
    echo "Usage: $0 <repository-name> [options]"
    echo "Options:"
    echo "  -l, --license <license>     License type (Apache-2.0, MIT)"
    echo "  -v, --visibility <vis>      Repository visibility (private, public)"
    echo "  -p, --project <project>     Azure DevOps project name"
    echo "  -o, --org <organization>    Azure DevOps organization"
    echo "  -h, --help                  Display this help message"
    exit 1
}

# Function to check if running in WSL
is_wsl() {
    if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to read configuration
read_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Configuration file not found. Creating one..."
        create_config
    fi
    
    # Read configuration based on environment
    if is_wsl; then
        REPO_PATH=$(jq -r '.WSLPath // empty' "$CONFIG_FILE")
    else
        REPO_PATH=$(jq -r '.LinuxPath // .WSLPath // empty' "$CONFIG_FILE")
    fi
    
    AZURE_ORG=$(jq -r '.AzureOrganization // empty' "$CONFIG_FILE")
    AZURE_PROJECT=$(jq -r '.AzureProject // empty' "$CONFIG_FILE")
    COMPANY_NAME=$(jq -r '.CompanyName // empty' "$CONFIG_FILE")
    DEFAULT_BRANCH=$(jq -r '.DefaultBranch // "master"' "$CONFIG_FILE")
    REPO_VISIBILITY=$(jq -r '.RepositoryVisibility // "private"' "$CONFIG_FILE")
    DEFAULT_LICENSE=$(jq -r '.DefaultLicense // "MIT"' "$CONFIG_FILE")
    ARTIFACT_FEED=$(jq -r '.ArtifactFeed // "dotnet-packages"' "$CONFIG_FILE")
}

# Function to create configuration
create_config() {
    echo "Setting up Azure DevOps configuration..."
    
    read -p "Enter your Azure DevOps organization name: " azure_org
    read -p "Enter your Azure DevOps project name: " azure_project
    read -p "Enter your company name: " company_name
    read -p "Enter default artifact feed name (default: dotnet-packages): " artifact_feed
    artifact_feed=${artifact_feed:-dotnet-packages}
    
    # Determine paths based on environment
    if is_wsl; then
        echo "WSL environment detected."
        default_path="/mnt/c/Source"
        read -p "Enter WSL repository path (default: $default_path): " wsl_path
        wsl_path=${wsl_path:-$default_path}
        
        # Convert WSL path to Windows path for the config
        windows_path=$(echo "$wsl_path" | sed 's|/mnt/c|C:|' | sed 's|/|\\|g')
        
        config_json=$(jq -n \
            --arg ao "$azure_org" \
            --arg ap "$azure_project" \
            --arg cn "$company_name" \
            --arg wp "$windows_path" \
            --arg wslp "$wsl_path" \
            --arg af "$artifact_feed" \
            '{
                AzureOrganization: $ao,
                AzureProject: $ap,
                CompanyName: $cn,
                WindowsPath: $wp,
                WSLPath: $wslp,
                DefaultBranch: "master",
                RepositoryVisibility: "private",
                DefaultLicense: "MIT",
                ArtifactFeed: $af
            }')
    else
        default_path="$HOME/source"
        read -p "Enter repository path (default: $default_path): " repo_path
        repo_path=${repo_path:-$default_path}
        
        config_json=$(jq -n \
            --arg ao "$azure_org" \
            --arg ap "$azure_project" \
            --arg cn "$company_name" \
            --arg lp "$repo_path" \
            --arg af "$artifact_feed" \
            '{
                AzureOrganization: $ao,
                AzureProject: $ap,
                CompanyName: $cn,
                LinuxPath: $lp,
                WSLPath: $lp,
                DefaultBranch: "master",
                RepositoryVisibility: "private",
                DefaultLicense: "MIT",
                ArtifactFeed: $af
            }')
    fi
    
    echo "$config_json" > "$CONFIG_FILE"
    echo "Configuration saved to $CONFIG_FILE"
}

# Function to check Azure CLI authentication
check_azure_cli() {
    if ! command -v az &> /dev/null; then
        echo "Error: Azure CLI is not installed. Please install it first."
        echo "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    
    # Check if logged in
    if ! az account show &> /dev/null; then
        echo "Not logged in to Azure CLI. Please log in..."
        az login
    fi
    
    # Check if Azure DevOps extension is installed
    if ! az extension show --name azure-devops &> /dev/null; then
        echo "Installing Azure DevOps extension..."
        az extension add --name azure-devops
    fi
}

# Function to create repository
create_repository() {
    local repo_name=$1
    local visibility=$2
    
    echo "Creating Azure DevOps repository: $repo_name"
    
    # Set defaults for Azure DevOps
    az devops configure --defaults organization="https://dev.azure.com/$AZURE_ORG" project="$AZURE_PROJECT"
    
    # Create repository
    repo_info=$(az repos create --name "$repo_name" --detect false -o json)
    repo_id=$(echo "$repo_info" | jq -r '.id')
    
    echo "Repository created with ID: $repo_id"
    
    # Initialize with README
    echo "# $repo_name" > README.md
    echo "" >> README.md
    echo "## Overview" >> README.md
    echo "" >> README.md
    echo "This repository contains..." >> README.md
    
    git add README.md
    git commit -m "Initial commit"
    
    # Set remote
    remote_url=$(echo "$repo_info" | jq -r '.remoteUrl')
    git remote add origin "$remote_url"
    
    return 0
}

# Function to setup Azure Artifacts feed
setup_artifact_feed() {
    local feed_name=$1
    
    echo "Checking Azure Artifacts feed: $feed_name"
    
    # Check if feed exists
    if ! az artifacts feed show --name "$feed_name" --org "https://dev.azure.com/$AZURE_ORG" &> /dev/null; then
        echo "Creating Azure Artifacts feed: $feed_name"
        az artifacts feed create \
            --name "$feed_name" \
            --org "https://dev.azure.com/$AZURE_ORG" \
            --description "NuGet packages for .NET projects" \
            --only-allow-upstream-source \
            --include-upstream-sources
    fi
    
    # Set feed permissions (organization-scoped)
    echo "Setting feed permissions..."
    az artifacts feed permission update \
        --feed "$feed_name" \
        --org "https://dev.azure.com/$AZURE_ORG" \
        --role contributor \
        --identity "Project Collection Build Service ($AZURE_ORG)"
}

# Function to create nuget.config for Azure Artifacts
create_nuget_config() {
    local feed_name=$1
    
    cat > nuget.config << EOF
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="$feed_name" value="https://pkgs.dev.azure.com/$AZURE_ORG/$AZURE_PROJECT/_packaging/$feed_name/nuget/v3/index.json" />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" />
  </packageSources>
  <packageSourceMapping>
    <packageSource key="$feed_name">
      <package pattern="$COMPANY_NAME.*" />
    </packageSource>
    <packageSource key="nuget.org">
      <package pattern="*" />
    </packageSource>
  </packageSourceMapping>
</configuration>
EOF
}

# Function to create pipeline
create_pipeline() {
    local repo_name=$1
    local script_dir=$(dirname "$(readlink -f "$0")")
    local pipeline_dir="$script_dir/../../../pipelines"
    
    echo "Setting up Azure Pipelines..."
    
    # Copy pipeline files
    mkdir -p .azuredevops
    cp "$pipeline_dir/dotnet-ci-cd.yml" azure-pipelines.yml
    cp "$pipeline_dir/security.yml" .azuredevops/security-pipeline.yml
    
    # Create pipeline in Azure DevOps
    pipeline_info=$(az pipelines create \
        --name "$repo_name-CI-CD" \
        --repository "$repo_name" \
        --repository-type tfsgit \
        --branch "$DEFAULT_BRANCH" \
        --yml-path "azure-pipelines.yml" \
        --skip-first-run true \
        -o json)
    
    pipeline_id=$(echo "$pipeline_info" | jq -r '.id')
    
    # Create security pipeline
    az pipelines create \
        --name "$repo_name-Security" \
        --repository "$repo_name" \
        --repository-type tfsgit \
        --branch "$DEFAULT_BRANCH" \
        --yml-path ".azuredevops/security-pipeline.yml" \
        --skip-first-run true
    
    echo "Pipelines created successfully"
}

# Function to setup branch policies
setup_branch_policies() {
    local repo_id=$1
    
    echo "Setting up branch policies for $DEFAULT_BRANCH..."
    
    # Create branch policy for PR builds
    az repos policy build create \
        --repository-id "$repo_id" \
        --branch "$DEFAULT_BRANCH" \
        --enabled true \
        --blocking true \
        --queue-on-source-update-only false \
        --display-name "PR Build Validation" \
        --build-definition-id "$pipeline_id" \
        --valid-duration 720
    
    # Require PR reviews
    az repos policy required-reviewer create \
        --repository-id "$repo_id" \
        --branch "$DEFAULT_BRANCH" \
        --enabled true \
        --blocking true \
        --message "At least one reviewer required"
    
    # Require linked work items
    az repos policy work-item-linking create \
        --repository-id "$repo_id" \
        --branch "$DEFAULT_BRANCH" \
        --enabled true \
        --blocking false
}

# Function to create variable groups
create_variable_groups() {
    echo "Creating variable groups..."
    
    # Development secrets
    az pipelines variable-group create \
        --name "development-secrets" \
        --variables ASPNETCORE_ENVIRONMENT=Development \
        --authorize true \
        --description "Development environment secrets"
    
    # Staging secrets
    az pipelines variable-group create \
        --name "staging-secrets" \
        --variables ASPNETCORE_ENVIRONMENT=Staging \
        --authorize true \
        --description "Staging environment secrets"
    
    # Production secrets
    az pipelines variable-group create \
        --name "production-secrets" \
        --variables ASPNETCORE_ENVIRONMENT=Production \
        --authorize true \
        --description "Production environment secrets"
}

# Function to setup project structure
setup_project_structure() {
    local repo_name=$1
    local license=$2
    
    echo "Setting up .NET project structure..."
    
    # Create directories
    mkdir -p src tests docs .config .azuredevops
    
    # Create solution
    dotnet new sln -n "$repo_name"
    
    # Create main project
    cd src
    dotnet new classlib -n "$repo_name" -f net9.0
    cd ..
    dotnet sln add "src/$repo_name/$repo_name.csproj"
    
    # Create test project
    cd tests
    dotnet new xunit -n "$repo_name.Tests" -f net9.0
    cd ..
    dotnet sln add "tests/$repo_name.Tests/$repo_name.Tests.csproj"
    
    # Add project reference
    dotnet add "tests/$repo_name.Tests/$repo_name.Tests.csproj" reference "src/$repo_name/$repo_name.csproj"
    
    # Create .gitignore
    create_gitignore
    
    # Create license file
    create_license "$license"
    
    # Create version.json for nbgv
    create_version_json
    
    # Install nbgv
    dotnet tool install -g nbgv || true
    nbgv install
}

# Function to create .gitignore
create_gitignore() {
    curl -s https://raw.githubusercontent.com/github/gitignore/main/VisualStudio.gitignore -o .gitignore
    echo "" >> .gitignore
    echo "# Azure DevOps" >> .gitignore
    echo ".azuredevops/local/" >> .gitignore
    echo "*.user" >> .gitignore
}

# Function to create license
create_license() {
    local license=$1
    
    case $license in
        "MIT")
            create_mit_license
            ;;
        "Apache-2.0")
            create_apache_license
            ;;
        *)
            echo "Unknown license: $license"
            ;;
    esac
}

# Function to create MIT license
create_mit_license() {
    cat > LICENSE << EOF
MIT License

Copyright (c) $(date +%Y) $COMPANY_NAME

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
EOF
}

# Function to create Apache license
create_apache_license() {
    curl -s https://www.apache.org/licenses/LICENSE-2.0.txt -o LICENSE
}

# Function to create version.json
create_version_json() {
    cat > version.json << EOF
{
  "\$schema": "https://raw.githubusercontent.com/dotnet/Nerdbank.GitVersioning/master/src/NerdBank.GitVersioning/version.schema.json",
  "version": "1.0-alpha",
  "assemblyVersion": {
    "precision": "major.minor"
  },
  "publicReleaseRefSpec": [
    "^refs/heads/$DEFAULT_BRANCH\$",
    "^refs/heads/release/.*\$"
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
EOF
}

# Main function
main() {
    # Parse arguments
    if [ $# -eq 0 ]; then
        usage
    fi
    
    REPO_NAME=$1
    shift
    
    # Read configuration
    read_config
    
    # Set defaults
    LICENSE=${LICENSE:-$DEFAULT_LICENSE}
    VISIBILITY=${VISIBILITY:-$REPO_VISIBILITY}
    PROJECT=${PROJECT:-$AZURE_PROJECT}
    ORGANIZATION=${ORGANIZATION:-$AZURE_ORG}
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case $1 in
            -l|--license)
                LICENSE="$2"
                shift 2
                ;;
            -v|--visibility)
                VISIBILITY="$2"
                shift 2
                ;;
            -p|--project)
                PROJECT="$2"
                shift 2
                ;;
            -o|--org)
                ORGANIZATION="$2"
                shift 2
                ;;
            -h|--help)
                usage
                ;;
            *)
                echo "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    # Update variables if overridden
    AZURE_PROJECT=$PROJECT
    AZURE_ORG=$ORGANIZATION
    
    # Check Azure CLI
    check_azure_cli
    
    # Create repository directory
    REPO_DIR="$REPO_PATH/$REPO_NAME"
    if [ -d "$REPO_DIR" ]; then
        echo "Error: Directory $REPO_DIR already exists"
        exit 1
    fi
    
    mkdir -p "$REPO_DIR"
    cd "$REPO_DIR"
    
    # Initialize git
    git init -b "$DEFAULT_BRANCH"
    
    # Setup artifact feed
    setup_artifact_feed "$ARTIFACT_FEED"
    
    # Create nuget.config
    create_nuget_config "$ARTIFACT_FEED"
    
    # Setup project structure
    setup_project_structure "$REPO_NAME" "$LICENSE"
    
    # Create repository in Azure DevOps
    create_repository "$REPO_NAME" "$VISIBILITY"
    
    # Create variable groups
    create_variable_groups
    
    # Create pipeline
    create_pipeline "$REPO_NAME"
    
    # Setup branch policies
    setup_branch_policies "$repo_id"
    
    # Commit and push
    git add .
    git commit -m "Initial project setup with Azure DevOps CI/CD"
    git push -u origin "$DEFAULT_BRANCH"
    
    # Create develop branch
    git checkout -b develop
    git push -u origin develop
    
    # Switch back to default branch
    git checkout "$DEFAULT_BRANCH"
    
    echo ""
    echo "✅ Repository setup complete!"
    echo "📁 Location: $REPO_DIR"
    echo "🔗 Azure DevOps: https://dev.azure.com/$AZURE_ORG/$AZURE_PROJECT/_git/$REPO_NAME"
    echo "📦 Artifact Feed: https://dev.azure.com/$AZURE_ORG/$AZURE_PROJECT/_artifacts/feed/$ARTIFACT_FEED"
    echo ""
    echo "Next steps:"
    echo "1. Configure Key Vault secrets in variable groups"
    echo "2. Set up service connections if needed"
    echo "3. Run the pipeline to verify setup"
}

# Run main function
main "$@"