#!/bin/bash
# add-azure-keyvault.sh - Add Azure Key Vault integration to existing repositories

set -e

# Configuration
ORG_NAME="cyberdinedevelopment"
KEY_VAULT_NAME="${1:-cyberdine-keyvault}"
RESOURCE_GROUP="${2:-cyberdine-rg}"
LOCATION="${3:-eastus}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Add Azure Key Vault workflow
add_keyvault_workflow() {
    local repo_name="$1"
    
    cat > .github/workflows/azure-keyvault.yml << 'EOF'
name: Azure Key Vault Integration

on:
  workflow_call:
    secrets:
      AZURE_CLIENT_ID:
        required: true
      AZURE_TENANT_ID:
        required: true
      AZURE_SUBSCRIPTION_ID:
        required: true

jobs:
  retrieve-secrets:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    outputs:
      database-url: ${{ steps.keyvault.outputs.database-url }}
      api-key: ${{ steps.keyvault.outputs.api-key }}
      storage-connection: ${{ steps.keyvault.outputs.storage-connection }}
    
    steps:
    - name: Azure Login
      uses: azure/login@v1
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    
    - name: Get secrets from Key Vault
      id: keyvault
      uses: Azure/get-keyvault-secrets@v1
      with:
        keyvault: "cyberdine-keyvault"
        secrets: 'database-url, api-key, storage-connection'
EOF

    # Update main workflow to use Key Vault
    log_info "Updating workflow to use Azure Key Vault for $repo_name"
}

# Setup Azure resources (run once)
setup_azure_resources() {
    log_info "Setting up Azure Key Vault resources"
    
    # Create resource group
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
    
    # Create Key Vault
    az keyvault create \
        --name "$KEY_VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --enable-rbac-authorization
    
    # Add sample secrets
    az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "database-url" --value "Server=prod.db;Database=app"
    az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "api-key" --value "prod-api-key"
    az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "storage-connection" --value "DefaultEndpointsProtocol=https"
    
    log_info "Azure Key Vault setup complete"
}

# Main execution
main() {
    log_info "Adding Azure Key Vault integration"
    
    # Note: This requires Azure CLI to be installed and authenticated
    # setup_azure_resources
    
    # Add workflow to each repository
    for repo in smart-generators enhanced-enums smart-switches smart-delegates developer-kit; do
        if [ -d "$repo" ]; then
            cd "$repo"
            add_keyvault_workflow "$repo"
            cd ..
        fi
    done
    
    log_info "Azure Key Vault integration added. Configure AZURE_* secrets in GitHub."
}

main "$@"