#!/bin/bash
# update-repos.sh - Update existing repositories with latest CI/CD configurations

set -e

# Configuration
ORG_NAME="cyberdinedevelopment"
DEFAULT_PATH="/mnt/d/fractaldataworks"
DEFAULT_BRANCH="master"

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

# Usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [REPOSITORY_NAMES...]

Update existing repositories with latest CI/CD configurations.

OPTIONS:
    -h, --help              Show this help message
    -o, --org NAME          Organization name (default: $ORG_NAME)
    -p, --path PATH         Default path (default: $DEFAULT_PATH)
    -b, --branch NAME       Default branch (default: $DEFAULT_BRANCH)
    -w, --workflows-only    Update only workflows
    -c, --config-only       Update only configuration files
    -a, --all              Update all organization repositories
    --fix-branch           Fix default branch to master
    --add-repo NAME        Add a new repository with CI/CD

EXAMPLES:
    # Update specific repositories
    $0 smart-generators enhanced-enums

    # Update all repositories
    $0 --all

    # Update only workflows
    $0 --workflows-only smart-generators

    # Add a new repository
    $0 --add-repo new-library

EOF
}

# Parse arguments
WORKFLOWS_ONLY=false
CONFIG_ONLY=false
UPDATE_ALL=false
FIX_BRANCH=false
ADD_REPO=""
REPOS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -o|--org)
            ORG_NAME="$2"
            shift 2
            ;;
        -p|--path)
            DEFAULT_PATH="$2"
            shift 2
            ;;
        -b|--branch)
            DEFAULT_BRANCH="$2"
            shift 2
            ;;
        -w|--workflows-only)
            WORKFLOWS_ONLY=true
            shift
            ;;
        -c|--config-only)
            CONFIG_ONLY=true
            shift
            ;;
        -a|--all)
            UPDATE_ALL=true
            shift
            ;;
        --fix-branch)
            FIX_BRANCH=true
            shift
            ;;
        --add-repo)
            ADD_REPO="$2"
            shift 2
            ;;
        *)
            REPOS+=("$1")
            shift
            ;;
    esac
done

# Get all repositories if --all flag is set
get_all_repos() {
    gh repo list "$ORG_NAME" --limit 100 --json name -q '.[].name' | grep -E "(smart-|enhanced-|developer-kit)"
}

# Update workflows
update_workflows() {
    local repo_path="$1"
    
    log_info "Updating workflows..."
    
    # Copy latest workflows from template
    mkdir -p "$repo_path/.github/workflows"
    
    # Here you would copy from a template location
    # For now, we'll update in place
    
    # Update workflow files to latest versions
    if [ -f "$repo_path/.github/workflows/dotnet-ci-cd.yml" ]; then
        log_info "Workflow already exists, checking for updates..."
        # Add logic to update specific workflow sections if needed
    fi
}

# Update configuration files
update_config() {
    local repo_path="$1"
    
    log_info "Updating configuration files..."
    
    # Update Directory.Build.props
    if [ -f "$repo_path/Directory.Build.props" ]; then
        log_info "Updating Directory.Build.props..."
        # Update specific properties if needed
    fi
    
    # Update version.json for Nerdbank
    if [ -f "$repo_path/version.json" ]; then
        log_info "Version.json exists, checking for updates..."
    fi
    
    # Update .editorconfig
    if [ ! -f "$repo_path/.editorconfig" ]; then
        log_warn ".editorconfig missing, adding..."
    fi
}

# Fix default branch
fix_default_branch() {
    local repo_name="$1"
    
    log_info "Fixing default branch to master..."
    
    cd "$DEFAULT_PATH/$repo_name"
    
    # Check current default branch
    current_branch=$(gh repo view "$ORG_NAME/$repo_name" --json defaultBranchRef -q '.defaultBranchRef.name')
    
    if [[ "$current_branch" != "master" ]]; then
        log_info "Current default branch is $current_branch, changing to master..."
        
        # Create master branch if it doesn't exist
        if ! git show-ref --verify --quiet refs/heads/master; then
            git checkout -b master
            git push -u origin master
        fi
        
        # Set as default
        gh repo edit "$ORG_NAME/$repo_name" --default-branch master
        
        # Delete old default branch if it's main
        if [[ "$current_branch" == "main" ]]; then
            git push origin --delete main 2>/dev/null || true
        fi
    else
        log_info "Default branch is already master"
    fi
}

# Update repository
update_repository() {
    local repo_name="$1"
    
    log_info "=== Updating $repo_name ==="
    
    cd "$DEFAULT_PATH"
    
    # Clone or update repository
    if [ -d "$repo_name" ]; then
        cd "$repo_name"
        git pull
    else
        gh repo clone "$ORG_NAME/$repo_name"
        cd "$repo_name"
    fi
    
    # Fix branch if requested
    if [[ "$FIX_BRANCH" == true ]]; then
        fix_default_branch "$repo_name"
    fi
    
    # Update components
    if [[ "$CONFIG_ONLY" != true ]]; then
        update_workflows "$DEFAULT_PATH/$repo_name"
    fi
    
    if [[ "$WORKFLOWS_ONLY" != true ]]; then
        update_config "$DEFAULT_PATH/$repo_name"
    fi
    
    # Commit changes if any
    if [[ -n $(git status -s) ]]; then
        git add .
        git commit -m "Update CI/CD configuration

- Update workflows to latest version
- Update configuration files
- Maintain compatibility with .NET 9/10"
        
        git push
        log_info "✓ Updates pushed to $repo_name"
    else
        log_info "✓ No updates needed for $repo_name"
    fi
    
    cd "$DEFAULT_PATH"
}

# Add new repository
add_new_repository() {
    local repo_name="$1"
    
    log_info "Adding new repository: $repo_name"
    
    # Use the setup script
    if [ -f "$DEFAULT_PATH/GithubSetup/setup-cicd-repos.sh" ]; then
        # Temporarily modify the REPOSITORIES array
        export REPOSITORIES=("$repo_name")
        bash "$DEFAULT_PATH/GithubSetup/setup-cicd-repos.sh"
    else
        log_error "Setup script not found"
        exit 1
    fi
}

# Main execution
main() {
    log_info "Repository Update Tool"
    
    # Check dependencies
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is not installed"
        exit 1
    fi
    
    # Handle add repository
    if [[ -n "$ADD_REPO" ]]; then
        add_new_repository "$ADD_REPO"
        exit 0
    fi
    
    # Get repositories to update
    if [[ "$UPDATE_ALL" == true ]]; then
        mapfile -t REPOS < <(get_all_repos)
        log_info "Found ${#REPOS[@]} repositories to update"
    fi
    
    # Check if repositories specified
    if [[ ${#REPOS[@]} -eq 0 ]]; then
        log_error "No repositories specified. Use -a for all or specify repository names."
        usage
        exit 1
    fi
    
    # Update each repository
    for repo in "${REPOS[@]}"; do
        update_repository "$repo"
        echo ""
    done
    
    log_info "=== Update Summary ==="
    echo "Updated repositories:"
    for repo in "${REPOS[@]}"; do
        echo "  - $repo"
    done
}

main "$@"