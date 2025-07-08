#!/bin/bash

# Unified Repository Creation Script
# Prompts for platform choice (GitHub or Azure DevOps)

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo "Usage: $0 <repository-name> [options]"
    echo "Options:"
    echo "  -p, --platform <platform>   Platform (github, azure)"
    echo "  -h, --help                  Display this help message"
    echo ""
    echo "If platform is not specified, you will be prompted to choose."
    exit 1
}

# Parse arguments
if [ $# -eq 0 ]; then
    usage
fi

REPO_NAME=$1
PLATFORM=""
shift

# Parse options
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            # Pass through other arguments
            break
            ;;
    esac
done

# Validate platform if provided
if [ -n "$PLATFORM" ]; then
    if [[ "$PLATFORM" != "github" && "$PLATFORM" != "azure" ]]; then
        echo -e "${YELLOW}Invalid platform: $PLATFORM${NC}"
        echo "Valid options are: github, azure"
        exit 1
    fi
fi

# Prompt for platform if not provided
if [ -z "$PLATFORM" ]; then
    echo -e "${CYAN}Choose your platform:${NC}"
    echo "1) GitHub"
    echo "2) Azure DevOps"
    echo ""
    read -p "Enter your choice (1 or 2): " choice
    
    case $choice in
        1)
            PLATFORM="github"
            ;;
        2)
            PLATFORM="azure"
            ;;
        *)
            echo -e "${YELLOW}Invalid choice. Please run again and select 1 or 2.${NC}"
            exit 1
            ;;
    esac
fi

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Execute the appropriate platform script
echo -e "${GREEN}Creating repository on $PLATFORM...${NC}"

if [ "$PLATFORM" == "github" ]; then
    exec "$SCRIPT_DIR/github/bash/new-repo.sh" "$REPO_NAME" "$@"
else
    exec "$SCRIPT_DIR/azure/bash/new-repo.sh" "$REPO_NAME" "$@"
fi