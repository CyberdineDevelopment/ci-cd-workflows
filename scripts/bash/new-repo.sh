#!/bin/bash
# new-repo.sh - Create a single new repository with CI/CD setup

set -e

# Default configuration
CONFIG_FILE="../../config.json"
REPO_NAME=""
LICENSE_OVERRIDE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --license)
            LICENSE_OVERRIDE="$2"
            shift 2
            ;;
        -h|--help)
            cat << 'EOF'
Usage: new-repo.sh REPOSITORY_NAME [OPTIONS]

Create a single new .NET repository with complete CI/CD setup.

ARGUMENTS:
    REPOSITORY_NAME     Name of the repository to create

OPTIONS:
    --config PATH       Path to configuration file (default: ./config.json)
    --license LICENSE   License to use (Apache-2.0 or MIT, default: from config)
    -h, --help          Show this help message

EXAMPLES:
    # Create a new repository
    ./new-repo.sh my-new-library
    
    # Use custom config
    ./new-repo.sh my-library --config ../config.json
    
    # Override license
    ./new-repo.sh my-library --license MIT

EOF
            exit 0
            ;;
        *)
            if [[ -z "$REPO_NAME" ]]; then
                REPO_NAME="$1"
            else
                echo "Error: Unknown option or too many arguments: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if repository name provided
if [[ -z "$REPO_NAME" ]]; then
    echo "Error: Repository name is required"
    echo "Usage: $0 REPOSITORY_NAME [OPTIONS]"
    exit 1
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create configuration interactively
create_config() {
    log_info "Creating new configuration"
    
    # Ensure config directory exists
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    echo ""
    echo "=== CI/CD Configuration Setup ==="
    echo ""
    
    # GitHub Organization
    read -p "GitHub Organization name: " github_org
    while [[ -z "$github_org" ]]; do
        read -p "GitHub Organization name (required): " github_org
    done
    
    # Company Name
    read -p "Company name: " company_name
    while [[ -z "$company_name" ]]; do
        read -p "Company name (required): " company_name
    done
    
    # WSL path
    wsl_default="/home/$USER/projects"
    read -p "WSL path for repositories ($wsl_default): " wsl_path
    wsl_path="${wsl_path:-$wsl_default}"
    
    # Windows path  
    windows_default="D:\\fractaldataworks"
    read -p "Windows path for repositories ($windows_default): " windows_path
    windows_path="${windows_path:-$windows_default}"
    
    # Repository visibility
    echo ""
    echo "Repository visibility options:"
    echo "  1) Private (recommended for internal projects)"
    echo "  2) Public (for open source projects)"
    read -p "Select repository visibility (1-2): " vis_choice
    case $vis_choice in
        2) repo_visibility="public" ;;
        *) repo_visibility="private" ;;
    esac
    
    # Default branch
    read -p "Default branch name (master): " default_branch
    default_branch="${default_branch:-master}"
    
    # Default license
    echo ""
    echo "Default license options:"
    echo "  1) Apache-2.0 (recommended for business)"
    echo "  2) MIT (simple permissive)"
    read -p "Select default license (1-2): " license_choice
    case $license_choice in
        2) default_license="MIT" ;;
        *) default_license="Apache-2.0" ;;
    esac
    
    # Save configuration
    cat > "$CONFIG_FILE" << EOF
{
  "GitHubOrganization": "$github_org",
  "CompanyName": "$company_name",
  "WSLPath": "$wsl_path",
  "WindowsPath": "$windows_path",
  "DefaultBranch": "$default_branch",
  "RepositoryVisibility": "$repo_visibility",
  "DefaultLicense": "$default_license",
  "ScriptPath": "$(dirname "$0")",
  "LastUpdated": "$(date '+%Y-%m-%d %H:%M:%S')"
}
EOF
    
    log_info "Configuration saved to: $CONFIG_FILE"
}

# Load or create configuration
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_info "Configuration file not found. Setting up configuration..."
        create_config
    fi
    
    log_info "Loading configuration from: $CONFIG_FILE"
    
    # Load configuration using jq if available, otherwise use grep/sed
    if command -v jq &> /dev/null; then
        ORG_NAME=$(jq -r '.GitHubOrganization' "$CONFIG_FILE")
        COMPANY_NAME=$(jq -r '.CompanyName' "$CONFIG_FILE")
        DEFAULT_PATH=$(jq -r '.WSLPath' "$CONFIG_FILE")
        DEFAULT_BRANCH=$(jq -r '.DefaultBranch' "$CONFIG_FILE")
        REPO_VISIBILITY=$(jq -r '.RepositoryVisibility' "$CONFIG_FILE")
        DEFAULT_LICENSE=$(jq -r '.DefaultLicense' "$CONFIG_FILE")
    else
        # Fallback parsing without jq
        ORG_NAME=$(grep '"GitHubOrganization"' "$CONFIG_FILE" | sed 's/.*: *"\([^"]*\)".*/\1/')
        COMPANY_NAME=$(grep '"CompanyName"' "$CONFIG_FILE" | sed 's/.*: *"\([^"]*\)".*/\1/')
        DEFAULT_PATH=$(grep '"WSLPath"' "$CONFIG_FILE" | sed 's/.*: *"\([^"]*\)".*/\1/')
        DEFAULT_BRANCH=$(grep '"DefaultBranch"' "$CONFIG_FILE" | sed 's/.*: *"\([^"]*\)".*/\1/')
        REPO_VISIBILITY=$(grep '"RepositoryVisibility"' "$CONFIG_FILE" | sed 's/.*: *"\([^"]*\)".*/\1/')
        DEFAULT_LICENSE=$(grep '"DefaultLicense"' "$CONFIG_FILE" | sed 's/.*: *"\([^"]*\)".*/\1/')
    fi
    
    
    # Validate required values
    if [[ -z "$ORG_NAME" || -z "$COMPANY_NAME" || -z "$DEFAULT_PATH" ]]; then
        log_error "Invalid configuration. Required values missing."
        log_info "Recreating configuration..."
        create_config
    fi
}

# Check dependencies
check_dependencies() {
    for dep in gh git dotnet; do
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
}

# Create repository
create_repository() {
    log_info "Creating repository: $ORG_NAME/$REPO_NAME"
    
    # Ensure the default path exists
    mkdir -p "$DEFAULT_PATH"
    cd "$DEFAULT_PATH"
    
    # Create repository
    local visibility_flag="--${REPO_VISIBILITY}"
    local repo_license="${LICENSE_OVERRIDE:-$DEFAULT_LICENSE}"
    local description="$REPO_NAME library for .NET development"
    
    # Try to create repository, but continue if it already exists
    if gh repo create "$ORG_NAME/$REPO_NAME" \
        $visibility_flag \
        --description "$description" \
        --gitignore "VisualStudio" \
        --license "$repo_license" 2>/dev/null; then
        log_info "✓ Repository created successfully"
    else
        log_info "Repository already exists, continuing with setup..."
    fi
    
    # Clone or navigate to existing repository
    if [[ -d "$REPO_NAME" ]]; then
        log_info "Local repository directory found, using existing clone"
        cd "$REPO_NAME"
        # Fix WSL git permissions for Windows filesystem
        git config core.filemode false
        git config core.autocrlf input
    else
        log_info "Cloning repository..."
        # Try to clone using git clone first
        if ! git clone "https://github.com/$ORG_NAME/$REPO_NAME.git" 2>/dev/null; then
            log_error "Git clone failed, likely due to WSL filesystem permission issues."
            echo ""
            echo "This usually happens when trying to clone to a Windows filesystem path."
            echo "Current path: $DEFAULT_PATH"
            echo ""
            read -p "Would you like to use a WSL filesystem path instead? (y/N): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo ""
                read -p "Enter new project path (e.g., /home/$USER/projects): " new_path
                if [[ -n "$new_path" ]]; then
                    # Update config and try again
                    if command -v jq &> /dev/null; then
                        jq --arg path "$new_path" '.DefaultPath = $path' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
                    else
                        sed -i "s|\"DefaultPath\": \"[^\"]*\"|\"DefaultPath\": \"$new_path\"|" "$CONFIG_FILE"
                    fi
                    DEFAULT_PATH="$new_path"
                    log_info "Updated configuration with new path: $DEFAULT_PATH"
                    
                    # Create new directory and try clone again
                    mkdir -p "$DEFAULT_PATH"
                    cd "$DEFAULT_PATH"
                    git clone "https://github.com/$ORG_NAME/$REPO_NAME.git"
                fi
            else
                log_error "Cannot proceed without a working git repository. Exiting."
                exit 1
            fi
        fi
        cd "$REPO_NAME"
        
        # Fix WSL git permissions for Windows filesystem  
        git config core.filemode false
        git config core.autocrlf input
    fi
    
    # Ensure we're on master branch (never use main)
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    if [[ "$current_branch" != "$DEFAULT_BRANCH" ]]; then
        if git show-ref --verify --quiet "refs/heads/$DEFAULT_BRANCH"; then
            git checkout "$DEFAULT_BRANCH"
        else
            git checkout -b "$DEFAULT_BRANCH"
            git push -u origin "$DEFAULT_BRANCH"
            gh repo edit "$ORG_NAME/$REPO_NAME" --default-branch "$DEFAULT_BRANCH"
            # Delete main branch if it exists
            if git show-ref --verify --quiet "refs/remotes/origin/main"; then
                git push origin --delete main 2>/dev/null || true
            fi
        fi
    fi
}

# Create README function
create_readme() {
    cat > README.md << EOF
# $REPO_NAME

Part of the $COMPANY_NAME toolkit.

## Build Status

[![Master Build](https://github.com/$ORG_NAME/$REPO_NAME/actions/workflows/dotnet-ci-cd.yml/badge.svg?branch=master)](https://github.com/$ORG_NAME/$REPO_NAME/actions/workflows/dotnet-ci-cd.yml)
[![Develop Build](https://github.com/$ORG_NAME/$REPO_NAME/actions/workflows/dotnet-ci-cd.yml/badge.svg?branch=develop)](https://github.com/$ORG_NAME/$REPO_NAME/actions/workflows/dotnet-ci-cd.yml)

## Release Status

![GitHub release (latest by date)](https://img.shields.io/github/v/release/$ORG_NAME/$REPO_NAME)
![GitHub release (latest by date including pre-releases)](https://img.shields.io/github/v/release/$ORG_NAME/$REPO_NAME?include_prereleases&label=pre-release)

## Package Status

![Nuget](https://img.shields.io/nuget/v/$COMPANY_NAME.$REPO_NAME)
![GitHub Packages](https://img.shields.io/badge/github%20packages-available-blue)

## Installation

\`\`\`bash
dotnet add package $COMPANY_NAME.$REPO_NAME
\`\`\`

## Development

This repository contains library packages for .NET development. To use these packages:

1. Reference the package in your project
2. Follow the documentation in the \`/docs\` folder
3. See examples in the \`/samples\` folder (if available)

## License

Apache-2.0
EOF
}

# Setup repository files with user confirmation
setup_repository_files() {
    log_info "Setting up CI/CD files for $REPO_NAME"
    
    # Check if this is an existing repository with content
    local is_existing_repo=false
    if [[ -f "README.md" || -f "Directory.Build.props" || -d ".github/workflows" ]]; then
        is_existing_repo=true
        echo ""
        echo "This appears to be an existing repository with content."
        echo "The following operations will modify/add files:"
        echo "  - CI/CD workflows (.github/workflows/)"
        echo "  - Build configuration (Directory.Build.props, version.json, global.json)"
        echo "  - Repository files (README.md, SECURITY.md, .editorconfig, etc.)"
        echo ""
        read -p "Do you want to proceed with CI/CD setup? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "CI/CD setup cancelled by user"
            return 0
        fi
    fi
    
    # Create directory structure
    log_info "Creating directory structure in $(pwd)"
    mkdir -p .github/workflows src tests docs .config
    log_info "Directories created successfully"
    
    # Copy workflow templates from the workflows directory
    local script_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
    local workflow_dir="$script_dir/../../workflows"
    if [[ -d "$workflow_dir" ]]; then
        cp "$workflow_dir/dotnet-ci-cd.yml" .github/workflows/ 2>/dev/null || true
        cp "$workflow_dir/security.yml" .github/workflows/ 2>/dev/null || true
        log_info "Copied CI/CD workflows from $workflow_dir"
    else
        log_error "Workflow directory not found at: $workflow_dir"
    fi
    
    # Create basic project files
    cat > global.json << EOF
{
  "sdk": {
    "version": "9.0",
    "rollForward": "latestFeature",
    "allowPrerelease": false
  }
}
EOF

    cat > Directory.Build.props << 'EOF'
<Project>
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <LangVersion>latest</LangVersion>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <!-- Treat warnings as errors only in CI for master/release branches -->
    <TreatWarningsAsErrors Condition="'$(CI)' == 'true' AND ('$(GITHUB_REF)' == 'refs/heads/master' OR $(GITHUB_REF.StartsWith('refs/heads/release/')))">true</TreatWarningsAsErrors>
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
    <NoWarn>$(NoWarn);CS1591</NoWarn>
    
    <!-- Package properties -->
    <Authors>$COMPANY_NAME</Authors>
    <Company>$COMPANY_NAME</Company>
    <Copyright>Copyright (c) $COMPANY_NAME $([System.DateTime]::Now.Year)</Copyright>
    <PackageLicenseExpression>$repo_license</PackageLicenseExpression>
    <RepositoryUrl>https://github.com/$ORG_NAME/$(MSBuildProjectName)</RepositoryUrl>
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

    cat > version.json << 'EOF'
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
EOF

    # Create README (ask if file exists)
    if [[ -f "README.md" && "$is_existing_repo" == true ]]; then
        echo ""
        read -p "README.md exists. Overwrite it? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Keeping existing README.md"
        else
            create_readme
        fi
    else
        create_readme
    fi
    
    # Create nuget.config in home directory for internal package dependencies
    mkdir -p ~/.nuget/NuGet
    cat > ~/.nuget/NuGet/NuGet.Config << EOF
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
    <add key="github" value="https://nuget.pkg.github.com/$ORG_NAME/index.json" />
  </packageSources>
  <packageSourceMapping>
    <packageSource key="nuget.org">
      <package pattern="*" />
    </packageSource>
    <packageSource key="github">
      <package pattern="$COMPANY_NAME.*" />
    </packageSource>
  </packageSourceMapping>
</configuration>
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

    # Create .github/dependabot.yml
    mkdir -p .github
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

# Configure repository settings
configure_repository() {
    log_info "Configuring repository settings"
    
    # Configure repository settings
    gh repo edit "$ORG_NAME/$REPO_NAME" \
        --enable-issues \
        --enable-wiki \
        --delete-branch-on-merge \
        --add-topic "dotnet,csharp,nuget" 2>/dev/null || true
}

# Commit and push
commit_and_push() {
    log_info "Committing and pushing initial setup"
    
    git add .
    git commit -m "Initial CI/CD setup with Nerdbank.GitVersioning

- Add GitHub Actions workflows for CI/CD
- Configure Nerdbank.GitVersioning with SemVer 2.0
- Add security scanning and SBOM generation
- Add repository structure and configuration files"
    
    git push -u origin "$DEFAULT_BRANCH"
}

# Main execution
main() {
    log_info "Creating new repository: $REPO_NAME"
    
    check_dependencies
    load_config
    
    log_info "Using configuration:"
    echo "  GitHub Organization: $ORG_NAME"
    echo "  Company Name: $COMPANY_NAME"
    echo "  Default Path: $DEFAULT_PATH"
    echo "  Repository Visibility: $REPO_VISIBILITY"
    echo "  Default Branch: $DEFAULT_BRANCH"
    echo ""
    
    create_repository
    setup_repository_files
    configure_repository
    commit_and_push
    
    log_info "✓ Repository $REPO_NAME setup completed successfully!"
    echo ""
    echo "Repository URL: https://github.com/$ORG_NAME/$REPO_NAME"
    echo "Local path: $DEFAULT_PATH/$REPO_NAME"
    echo ""
    echo "Next steps:"
    echo "1. Add your library code to the /src folder"
    echo "2. Add tests to the /tests folder"
    echo "3. Push your first commit to trigger CI/CD"
}

main "$@"