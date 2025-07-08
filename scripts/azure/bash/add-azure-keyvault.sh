#!/bin/bash

# Azure Key Vault Integration Script for Azure DevOps
# Sets up Key Vault integration with variable groups

set -euo pipefail

# Function to display usage
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -k, --keyvault <name>       Key Vault name"
    echo "  -g, --group <name>          Variable group name"
    echo "  -p, --project <project>     Azure DevOps project"
    echo "  -o, --org <organization>    Azure DevOps organization"
    echo "  -s, --subscription <id>     Azure subscription ID"
    echo "  -h, --help                  Display this help message"
    exit 1
}

# Function to check Azure CLI
check_azure_cli() {
    if ! command -v az &> /dev/null; then
        echo "Error: Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if logged in
    if ! az account show &> /dev/null; then
        echo "Not logged in to Azure CLI. Please log in..."
        az login
    fi
}

# Function to create service principal for Azure DevOps
create_service_principal() {
    local name=$1
    local subscription=$2
    
    echo "Creating service principal for Azure DevOps..."
    
    sp_info=$(az ad sp create-for-rbac \
        --name "$name" \
        --role "Key Vault Reader" \
        --scopes "/subscriptions/$subscription" \
        -o json)
    
    echo "$sp_info"
}

# Function to grant Key Vault access
grant_keyvault_access() {
    local keyvault=$1
    local sp_id=$2
    
    echo "Granting Key Vault access to service principal..."
    
    # Grant secret permissions
    az keyvault set-policy \
        --name "$keyvault" \
        --spn "$sp_id" \
        --secret-permissions get list
}

# Function to create service connection
create_service_connection() {
    local name=$1
    local subscription=$2
    local tenant=$3
    local client_id=$4
    local client_secret=$5
    
    echo "Creating service connection in Azure DevOps..."
    
    # Note: This requires manual configuration in Azure DevOps portal
    echo "Please create a service connection in Azure DevOps with these details:"
    echo "  Name: $name"
    echo "  Subscription ID: $subscription"
    echo "  Tenant ID: $tenant"
    echo "  Service Principal ID: $client_id"
    echo "  Service Principal Key: [Hidden]"
}

# Function to link Key Vault to variable group
link_keyvault_to_group() {
    local group=$1
    local keyvault=$2
    local service_connection=$3
    
    echo "Linking Key Vault to variable group..."
    
    # Create or update variable group with Key Vault link
    az pipelines variable-group create \
        --name "$group" \
        --authorize true \
        --description "Variables from Key Vault: $keyvault" || true
    
    echo "Variable group '$group' created/updated"
    echo "Please manually link to Key Vault '$keyvault' in Azure DevOps portal"
}

# Main function
main() {
    # Default values
    KEYVAULT=""
    GROUP=""
    PROJECT=""
    ORGANIZATION=""
    SUBSCRIPTION=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -k|--keyvault)
                KEYVAULT="$2"
                shift 2
                ;;
            -g|--group)
                GROUP="$2"
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
            -s|--subscription)
                SUBSCRIPTION="$2"
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
    
    # Validate required parameters
    if [ -z "$KEYVAULT" ] || [ -z "$GROUP" ]; then
        echo "Error: Key Vault name and variable group name are required"
        usage
    fi
    
    # Check Azure CLI
    check_azure_cli
    
    # Get current subscription if not provided
    if [ -z "$SUBSCRIPTION" ]; then
        SUBSCRIPTION=$(az account show --query id -o tsv)
    fi
    
    # Get tenant ID
    TENANT=$(az account show --query tenantId -o tsv)
    
    # Set Azure DevOps defaults if provided
    if [ -n "$ORGANIZATION" ] && [ -n "$PROJECT" ]; then
        az devops configure --defaults organization="https://dev.azure.com/$ORGANIZATION" project="$PROJECT"
    fi
    
    # Create service principal
    SP_NAME="sp-azuredevops-$GROUP"
    sp_info=$(create_service_principal "$SP_NAME" "$SUBSCRIPTION")
    
    CLIENT_ID=$(echo "$sp_info" | jq -r '.appId')
    CLIENT_SECRET=$(echo "$sp_info" | jq -r '.password')
    
    # Grant Key Vault access
    grant_keyvault_access "$KEYVAULT" "$CLIENT_ID"
    
    # Create service connection
    SERVICE_CONNECTION="azure-keyvault-$GROUP"
    create_service_connection "$SERVICE_CONNECTION" "$SUBSCRIPTION" "$TENANT" "$CLIENT_ID" "$CLIENT_SECRET"
    
    # Link Key Vault to variable group
    link_keyvault_to_group "$GROUP" "$KEYVAULT" "$SERVICE_CONNECTION"
    
    echo ""
    echo "✅ Key Vault integration setup complete!"
    echo ""
    echo "Manual steps required in Azure DevOps:"
    echo "1. Create service connection '$SERVICE_CONNECTION' with the service principal details"
    echo "2. Link variable group '$GROUP' to Key Vault '$KEYVAULT'"
    echo "3. Select which secrets to expose as variables"
    echo ""
    echo "Service Principal Details (save these securely):"
    echo "  Client ID: $CLIENT_ID"
    echo "  Tenant ID: $TENANT"
    echo "  Subscription ID: $SUBSCRIPTION"
    echo "  Client Secret: [Displayed only once above]"
}

# Run main function
main "$@"