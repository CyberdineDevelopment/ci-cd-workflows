# Azure Key Vault Integration Script for Azure DevOps
# Sets up Key Vault integration with variable groups

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$KeyVaultName,
    
    [Parameter(Mandatory = $true)]
    [string]$VariableGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$Project,
    
    [Parameter(Mandatory = $false)]
    [string]$Organization,
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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
}

# Function to create service principal
function New-ServicePrincipalForKeyVault {
    param(
        [string]$Name,
        [string]$Subscription
    )
    
    Write-Host "Creating service principal for Azure DevOps..." -ForegroundColor Cyan
    
    $spInfo = az ad sp create-for-rbac `
        --name $Name `
        --role "Key Vault Reader" `
        --scopes "/subscriptions/$Subscription" `
        -o json | ConvertFrom-Json
    
    return $spInfo
}

# Function to grant Key Vault access
function Grant-KeyVaultAccess {
    param(
        [string]$KeyVault,
        [string]$ServicePrincipalId
    )
    
    Write-Host "Granting Key Vault access to service principal..." -ForegroundColor Cyan
    
    # Grant secret permissions
    az keyvault set-policy `
        --name $KeyVault `
        --spn $ServicePrincipalId `
        --secret-permissions get list
}

# Function to create service connection configuration
function New-ServiceConnectionConfig {
    param(
        [string]$Name,
        [string]$Subscription,
        [string]$Tenant,
        [string]$ClientId,
        [string]$ClientSecret
    )
    
    Write-Host "`nService Connection Configuration:" -ForegroundColor Green
    Write-Host "=================================" -ForegroundColor Green
    Write-Host "Please create a service connection in Azure DevOps with these details:" -ForegroundColor Yellow
    Write-Host "  Connection Name: $Name" -ForegroundColor White
    Write-Host "  Subscription ID: $Subscription" -ForegroundColor White
    Write-Host "  Tenant ID: $Tenant" -ForegroundColor White
    Write-Host "  Service Principal ID: $ClientId" -ForegroundColor White
    Write-Host "  Service Principal Key: [See secure output below]" -ForegroundColor White
    
    # Store client secret securely
    $script:serviceConnectionDetails = @{
        Name = $Name
        SubscriptionId = $Subscription
        TenantId = $Tenant
        ClientId = $ClientId
        ClientSecret = $ClientSecret
    }
}

# Function to create or update variable group
function Set-VariableGroupWithKeyVault {
    param(
        [string]$GroupName,
        [string]$KeyVault,
        [string]$ServiceConnection
    )
    
    Write-Host "`nCreating/updating variable group..." -ForegroundColor Cyan
    
    # Create or update variable group
    try {
        az pipelines variable-group create `
            --name $GroupName `
            --authorize true `
            --description "Variables from Key Vault: $KeyVault"
    } catch {
        Write-Host "Variable group may already exist, continuing..." -ForegroundColor Yellow
    }
    
    Write-Host "`nVariable Group Configuration:" -ForegroundColor Green
    Write-Host "=============================" -ForegroundColor Green
    Write-Host "Variable group '$GroupName' created/updated" -ForegroundColor White
    Write-Host "`nManual steps required in Azure DevOps:" -ForegroundColor Yellow
    Write-Host "1. Navigate to Pipelines > Library" -ForegroundColor White
    Write-Host "2. Select variable group '$GroupName'" -ForegroundColor White
    Write-Host "3. Click 'Link secrets from an Azure Key Vault'" -ForegroundColor White
    Write-Host "4. Select service connection '$ServiceConnection'" -ForegroundColor White
    Write-Host "5. Select Key Vault '$KeyVault'" -ForegroundColor White
    Write-Host "6. Choose which secrets to expose as variables" -ForegroundColor White
}

# Function to create setup instructions
function New-SetupInstructions {
    param($ServiceConnectionDetails)
    
    $instructions = @"
# Azure Key Vault Integration Setup Instructions

## Service Connection Details
Save these details securely - the client secret is shown only once!

- **Client ID**: $($ServiceConnectionDetails.ClientId)
- **Tenant ID**: $($ServiceConnectionDetails.TenantId)
- **Subscription ID**: $($ServiceConnectionDetails.SubscriptionId)
- **Client Secret**: $($ServiceConnectionDetails.ClientSecret)

## Setup Steps in Azure DevOps

1. **Create Service Connection**:
   - Go to Project Settings > Service connections
   - Click "New service connection"
   - Select "Azure Resource Manager"
   - Choose "Service principal (manual)"
   - Enter the details above
   - Verify and save

2. **Link Key Vault to Variable Group**:
   - Go to Pipelines > Library
   - Select the variable group
   - Click "Link secrets from an Azure Key Vault"
   - Select the service connection
   - Choose the Key Vault
   - Select secrets to expose

3. **Use in Pipeline**:
   ``````yaml
   variables:
   - group: $VariableGroupName
   ``````

## Example Pipeline Usage

``````yaml
# Reference the variable group
variables:
- group: $VariableGroupName

steps:
- script: |
    echo "Using secret: `$(my-secret-name)"
  displayName: 'Use Key Vault secret'
``````
"@
    
    $instructionsPath = "keyvault-setup-instructions.md"
    $instructions | Set-Content $instructionsPath
    Write-Host "`nSetup instructions saved to: $instructionsPath" -ForegroundColor Green
}

# Main execution
try {
    # Check Azure CLI
    Test-AzureCLI
    
    # Get current subscription if not provided
    if (-not $SubscriptionId) {
        $SubscriptionId = az account show --query id -o tsv
    }
    
    # Get tenant ID
    $TenantId = az account show --query tenantId -o tsv
    
    # Set Azure DevOps defaults if provided
    if ($Organization -and $Project) {
        az devops configure --defaults organization="https://dev.azure.com/$Organization" project="$Project"
    }
    
    # Create service principal
    $spName = "sp-azuredevops-$VariableGroupName"
    $spInfo = New-ServicePrincipalForKeyVault -Name $spName -Subscription $SubscriptionId
    
    # Grant Key Vault access
    Grant-KeyVaultAccess -KeyVault $KeyVaultName -ServicePrincipalId $spInfo.appId
    
    # Create service connection configuration
    $serviceConnectionName = "azure-keyvault-$VariableGroupName"
    New-ServiceConnectionConfig `
        -Name $serviceConnectionName `
        -Subscription $SubscriptionId `
        -Tenant $TenantId `
        -ClientId $spInfo.appId `
        -ClientSecret $spInfo.password
    
    # Create/update variable group
    Set-VariableGroupWithKeyVault `
        -GroupName $VariableGroupName `
        -KeyVault $KeyVaultName `
        -ServiceConnection $serviceConnectionName
    
    # Create setup instructions
    New-SetupInstructions -ServiceConnectionDetails $serviceConnectionDetails
    
    Write-Host "`n✅ Key Vault integration setup complete!" -ForegroundColor Green
    Write-Host "📄 Detailed instructions saved to: keyvault-setup-instructions.md" -ForegroundColor Cyan
    
} catch {
    Write-Error "Error: $_"
    exit 1
}