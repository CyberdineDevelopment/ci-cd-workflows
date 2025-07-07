#!/bin/bash
# setup-all.sh - Setup the ci-cd-workflows repository and optionally create all repos

set -e

# Configuration
ORG_NAME="cyberdinedevelopment"
DEFAULT_PATH="/mnt/d/fractaldataworks"
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

# Main execution
main() {
    log_info "Complete CI/CD Setup for CyberDine Development"
    echo ""
    
    # Step 1: Create ci-cd-workflows repository
    log_info "Step 1: Creating ci-cd-workflows repository..."
    cd "$GITHUB_SETUP_PATH"
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
            gh repo create "$ORG_NAME/test-cicd-pipeline" \
                --private \
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
    echo "CI/CD Workflows Repository: https://github.com/$ORG_NAME/ci-cd-workflows"
    echo ""
    echo "Available scripts in ci-cd-workflows/scripts/:"
    echo "  Bash:"
    echo "    - setup-cicd-repos.sh      # Create new repositories"
    echo "    - update-repos.sh          # Update existing repositories"
    echo "    - add-azure-keyvault.sh    # Add Azure Key Vault integration"
    echo ""
    echo "  PowerShell:"
    echo "    - Setup-CICDRepos.ps1      # Create new repositories"
    echo "    - Update-Repos.ps1         # Update existing repositories"
    echo "    - Add-AzureKeyVault.ps1    # Add Azure Key Vault integration"
    echo ""
    echo "Next steps:"
    echo "1. Clone the ci-cd-workflows repository"
    echo "2. Use scripts from the scripts/ directory"
    echo "3. Add your library code to the /src folder of each repository"
}

main "$@"