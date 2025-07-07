#!/bin/bash
# setup-all.sh - Setup the ci-cd-workflows repository and optionally create all repos with configuration support

set -e

# Default configuration
ORG_NAME="cyberdinedevelopment"
DEFAULT_PATH="/mnt/d/fractaldataworks"
DEFAULT_BRANCH="master"
REPO_VISIBILITY="private"
CONFIG_FILE="./config.json"
RECONFIGURE_ALL=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --reconfigure)
            RECONFIGURE_ALL=true
            shift
            ;;
        -h|--help)
            cat << 'EOF'
Usage: setup-all.sh [OPTIONS]

Setup the complete CI/CD infrastructure with configuration management.

OPTIONS:
    --config PATH       Path to configuration file (default: ./config.json)
    --reconfigure       Force reconfiguration of all settings
    -h, --help          Show this help message

EXAMPLES:
    # First time setup (will prompt for configuration)
    ./setup-all.sh
    
    # Force reconfiguration
    ./setup-all.sh --reconfigure
    
    # Use custom config location
    ./setup-all.sh --config "../config.json"
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

GITHUB_SETUP_PATH="$DEFAULT_PATH/GithubSetup"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Load or create configuration
load_config() {
    if [[ "$RECONFIGURE_ALL" == true ]] || [[ ! -f "$CONFIG_FILE" ]]; then
        log_info "Setting up CI/CD configuration"
        
        # Ensure config directory exists
        mkdir -p "$(dirname "$CONFIG_FILE")"
        
        # Interactive configuration
        echo ""
        echo -e "${BLUE}=== CI/CD Configuration Setup ===${NC}"
        echo ""
        
        # Organization
        read -p "Organization name (default: $ORG_NAME): " org_input
        [[ -n "$org_input" ]] && ORG_NAME="$org_input"
        
        # Default path
        read -p "Default path for repositories (default: $DEFAULT_PATH): " path_input
        [[ -n "$path_input" ]] && DEFAULT_PATH="$path_input"
        
        # Repository visibility
        echo ""
        echo "Repository visibility options:"
        echo "  1) Private (recommended for internal projects)"
        echo "  2) Public (for open source projects)"
        read -p "Select repository visibility (1-2, default: 1): " vis_choice
        case $vis_choice in
            2) REPO_VISIBILITY="public" ;;
            *) REPO_VISIBILITY="private" ;;
        esac
        
        # Default branch
        read -p "Default branch name (default: $DEFAULT_BRANCH): " branch_input
        [[ -n "$branch_input" ]] && DEFAULT_BRANCH="$branch_input"
        
        # Save configuration
        cat > "$CONFIG_FILE" << EOF
{
  "Organization": "$ORG_NAME",
  "DefaultPath": "$DEFAULT_PATH",
  "DefaultBranch": "$DEFAULT_BRANCH",
  "RepositoryVisibility": "$REPO_VISIBILITY",
  "ScriptPath": "$(dirname "$0")",
  "LastUpdated": "$(date '+%Y-%m-%d %H:%M:%S')"
}
EOF
        log_info "Configuration saved to: $CONFIG_FILE"
    else
        log_info "Loading existing configuration from: $CONFIG_FILE"
        
        # Load configuration using jq if available, otherwise use grep/sed
        if command -v jq &> /dev/null; then
            ORG_NAME=$(jq -r '.Organization' "$CONFIG_FILE")
            DEFAULT_PATH=$(jq -r '.DefaultPath' "$CONFIG_FILE")
            DEFAULT_BRANCH=$(jq -r '.DefaultBranch' "$CONFIG_FILE")
            REPO_VISIBILITY=$(jq -r '.RepositoryVisibility' "$CONFIG_FILE")
        else
            # Fallback parsing without jq
            ORG_NAME=$(grep '"Organization"' "$CONFIG_FILE" | sed 's/.*: *"\([^"]*\)".*/\1/')
            DEFAULT_PATH=$(grep '"DefaultPath"' "$CONFIG_FILE" | sed 's/.*: *"\([^"]*\)".*/\1/')
            DEFAULT_BRANCH=$(grep '"DefaultBranch"' "$CONFIG_FILE" | sed 's/.*: *"\([^"]*\)".*/\1/')
            REPO_VISIBILITY=$(grep '"RepositoryVisibility"' "$CONFIG_FILE" | sed 's/.*: *"\([^"]*\)".*/\1/')
        fi
    fi
    
    # Update derived paths
    GITHUB_SETUP_PATH="$DEFAULT_PATH/GithubSetup"
}

# Main execution
main() {
    log_info "Complete CI/CD Setup for CyberDine Development"
    echo ""
    
    # Check dependencies
    for dep in gh git dotnet; do
        if ! command -v "$dep" &> /dev/null; then
            echo "Error: $dep is not installed"
            exit 1
        fi
    done
    
    # Check GitHub authentication
    if ! gh auth status &> /dev/null; then
        echo "Error: Not authenticated with GitHub. Run 'gh auth login' first."
        exit 1
    fi
    
    # Load or create configuration
    load_config
    
    echo ""
    log_info "Using configuration:"
    echo "  Organization: $ORG_NAME"
    echo "  Default Path: $DEFAULT_PATH"
    echo "  Repository Visibility: $REPO_VISIBILITY"
    echo "  Default Branch: $DEFAULT_BRANCH"
    echo ""
    
    # Ensure default path exists
    mkdir -p "$DEFAULT_PATH"
    
    # Step 1: Create ci-cd-workflows repository
    log_info "Step 1: Creating ci-cd-workflows repository..."
    cd "$GITHUB_SETUP_PATH"
    
    # Pass configuration to the create script
    export ORG_NAME DEFAULT_PATH DEFAULT_BRANCH REPO_VISIBILITY
    bash create-cicd-workflows-repo.sh
    
    echo ""
    log_info "Step 2: Repository setup options"
    echo "1) Create all 5 repositories (smart-generators, enhanced-enums, etc.)"
    echo "2) Create test repository only"
    echo "3) Skip repository creation"
    read -p "Select option (1-3): " -n 1 -r
    echo ""
    
    case $REPLY in
        1)
            log_info "Creating all repositories..."
            bash setup-cicd-repos.sh
            ;;
        2)
            log_info "Creating test repository..."
            cd "$DEFAULT_PATH"
            visibility_flag="--${REPO_VISIBILITY}"
            gh repo create "$ORG_NAME/test-cicd-pipeline" \
                $visibility_flag \
                --description "Test repository for CI/CD pipeline validation" \
                --gitignore "VisualStudio" \
                --license "MIT" \
                --confirm || log_warn "Test repository may already exist"
            ;;
        3)
            log_info "Skipping repository creation"
            ;;
        *)
            log_warn "Invalid option, skipping repository creation"
            ;;
    esac
    
    echo ""
    log_info "=== Setup Complete ==="
    echo ""
    echo -e "${BLUE}CI/CD Workflows Repository:${NC} https://github.com/$ORG_NAME/ci-cd-workflows"
    echo ""
    echo -e "${YELLOW}Configuration:${NC}"
    echo "  Organization: $ORG_NAME"
    echo "  Default Path: $DEFAULT_PATH"
    echo "  Repository Visibility: $REPO_VISIBILITY"
    echo "  Default Branch: $DEFAULT_BRANCH"
    echo ""
    echo -e "${YELLOW}Available scripts in ci-cd-workflows/scripts/:${NC}"
    echo ""
    echo -e "${BLUE}  Bash:${NC}"
    echo "    - setup-cicd-repos.sh      # Create new repositories"
    echo "    - update-repos.sh          # Update existing repositories"
    echo "    - add-azure-keyvault.sh    # Add Azure Key Vault integration"
    echo "    - setup-all.sh             # This script (with config management)"
    echo ""
    echo -e "${BLUE}  PowerShell:${NC}"
    echo "    - Setup-CICDRepos.ps1      # Create new repositories"
    echo "    - Update-Repos.ps1         # Update existing repositories"
    echo "    - Add-AzureKeyVault.ps1    # Add Azure Key Vault integration"
    echo "    - Setup-All.ps1            # PowerShell version (with config management)"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Clone the ci-cd-workflows repository"
    echo "2. Use scripts from the scripts/ directory"
    echo "3. Add your library code to the /src folder of each repository"
    echo "4. Update NUGET_API_KEY secret: gh secret set NUGET_API_KEY --org $ORG_NAME"
    echo "5. Configure GitHub teams (developers, devops, security)"
    echo ""
    echo -e "${GREEN}Configuration file: $CONFIG_FILE${NC}"
}

main "$@"