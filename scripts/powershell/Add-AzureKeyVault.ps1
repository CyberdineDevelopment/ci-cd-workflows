# Add-AzureKeyVault.ps1 - Add Azure Key Vault integration to existing repositories

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Organization = "cyberdinedevelopment",
    
    [Parameter(Mandatory = $false)]
    [string]$KeyVaultName = "cyberdine-keyvault",
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup = "cyberdine-rg",
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory = $false)]
    [string[]]$Repositories = @(
        "smart-generators",
        "enhanced-enums",
        "smart-switches",
        "smart-delegates",
        "developer-kit"
    )
)

# Logging functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] ${Message}" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] ${Message}" -ForegroundColor Yellow
}

# Add Azure Key Vault workflow
function Add-KeyVaultWorkflow {
    param([string]$RepoPath)
    
    $workflowPath = Join-Path $RepoPath ".github\workflows\azure-keyvault.yml"
    
    @'
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
'@ | Out-File -FilePath $workflowPath -Encoding utf8
    
    Write-Info "Added Azure Key Vault workflow to ${RepoPath}"
}

# Setup Azure resources (requires Azure CLI)
function Set-AzureResources {
    Write-Info "Setting up Azure Key Vault resources"
    
    # Check if Azure CLI is available
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Warn "Azure CLI is not installed. Skipping Azure resource creation."
        Write-Info "Install Azure CLI from: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        return
    }
    
    # Create resource group
    az group create --name $ResourceGroup --location $Location
    
    # Create Key Vault
    az keyvault create `
        --name $KeyVaultName `
        --resource-group $ResourceGroup `
        --location $Location `
        --enable-rbac-authorization
    
    # Add sample secrets
    az keyvault secret set --vault-name $KeyVaultName --name "database-url" --value "Server=prod.db;Database=app"
    az keyvault secret set --vault-name $KeyVaultName --name "api-key" --value "prod-api-key"
    az keyvault secret set --vault-name $KeyVaultName --name "storage-connection" --value "DefaultEndpointsProtocol=https"
    
    Write-Info "Azure Key Vault setup complete"
}

# Update repository workflows
function Update-RepositoryWorkflows {
    param([string]$RepoName)
    
    Write-Info "Updating workflows for ${RepoName}"
    
    # Clone or pull latest
    if (Test-Path $RepoName) {
        Set-Location $RepoName
        git pull
    } else {
        gh repo clone "${Organization}/${RepoName}"
        Set-Location $RepoName
    }
    
    # Add Key Vault workflow
    Add-KeyVaultWorkflow -RepoPath (Get-Location)
    
    # Update main workflow to use Key Vault
    $mainWorkflowPath = ".github\workflows\dotnet-ci-cd.yml"
    if (Test-Path $mainWorkflowPath) {
        Write-Info "Update the main workflow to call the Azure Key Vault workflow when needed"
    }
    
    # Commit and push
    git add .
    git commit -m "Add Azure Key Vault integration workflow" 2>$null
    if ($LASTEXITCODE -eq 0) {
        git push
        Write-Info "Pushed Azure Key Vault integration to ${RepoName}"
    } else {
        Write-Warn "No changes to commit for ${RepoName}"
    }
    
    Set-Location ..
}

# Main execution
function Main {
    Write-Info "Adding Azure Key Vault integration"
    
    # Optionally setup Azure resources
    $setupAzure = Read-Host "Setup Azure Key Vault resources? (requires Azure CLI) (y/n)"
    if ($setupAzure -eq 'y') {
        Set-AzureResources
    }
    
    # Update each repository
    foreach ($repo in $Repositories) {
        Update-RepositoryWorkflows -RepoName $repo
    }
    
    Write-Info "Azure Key Vault integration complete"
    Write-Host ""
    Write-Info "Next steps:"
    Write-Host "1. Configure Azure service principal for GitHub Actions"
    Write-Host "2. Add these organization secrets:"
    Write-Host "   - AZURE_CLIENT_ID"
    Write-Host "   - AZURE_TENANT_ID"
    Write-Host "   - AZURE_SUBSCRIPTION_ID"
    Write-Host "3. Update workflows to use Key Vault secrets"
}

Main