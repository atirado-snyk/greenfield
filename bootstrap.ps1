#!/usr/bin/env pwsh
#
# bootstrap.ps1 — one-time Azure setup for the Housing Notes CI/CD pipeline.
#
# Provisions the out-of-band "trust" layer that the GitHub Actions pipeline
# depends on but cannot create itself (see DEPLOY.md §8):
#   - application resource group
#   - user-assigned managed identity + GitHub OIDC federated credential (main only)
#   - role assignments: Contributor, RBAC Administrator (app RG),
#     Storage Blob Data Contributor (state account)
#   - Terraform remote-state backend (separate RG + storage account + container)
#   - required resource-provider registrations
#   - (optional) the three GitHub Actions secrets, if `gh` is authenticated
#
# Idempotent: safe to re-run. Existing resources are detected and reused.
#
# Prereqs: run in Azure Cloud Shell (PowerShell) or any shell with `az` logged in
# as a user holding Owner / User Access Administrator on the target subscription.
#
# Usage:
#   ./bootstrap.ps1 -SubscriptionId <sub-id> [-GitHubRepo atirado-snyk/greenfield] `
#       [-Location eastus] [-AppResourceGroup housing-notes-rg] `
#       [-StateResourceGroup housing-notes-tfstate-rg] `
#       [-IdentityName housing-notes-deployer] [-SetGitHubSecrets]
#
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [string]$GitHubRepo        = "atirado-snyk/greenfield",
    [string]$Location          = "eastus",
    [string]$AppResourceGroup  = "housing-notes-rg",
    [string]$StateResourceGroup = "housing-notes-tfstate-rg",
    [string]$IdentityName      = "housing-notes-deployer",
    [string]$StateContainer    = "tfstate",

    # Provide to reuse an existing state storage account; omit to generate one.
    [string]$StateStorageAccount = "",

    # Set the three Azure GitHub secrets via `gh` (requires `gh auth login`).
    [switch]$SetGitHubSecrets
)

$ErrorActionPreference = "Stop"
function Info($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "    $m"  -ForegroundColor Green }

# --- Resource providers the AKS + ACR stack needs (Terraform auto-registration
#     is disabled in infra/providers.tf, so they must be registered here). ---
$Providers = @(
    "Microsoft.ContainerService",
    "Microsoft.ContainerRegistry",
    "Microsoft.Network",
    "Microsoft.Compute",
    "Microsoft.OperationalInsights",
    "Microsoft.ManagedIdentity",
    "Microsoft.Storage"
)

# --- GitHub OIDC subject: trust ONLY workflow runs on main of this repo. ---
$FederatedCredName = "github-main"
$Subject           = "repo:${GitHubRepo}:ref:refs/heads/main"
$Issuer            = "https://token.actions.githubusercontent.com"
$Audience          = "api://AzureADTokenExchange"

Info "Selecting subscription $SubscriptionId"
az account set --subscription $SubscriptionId | Out-Null
$TenantId = az account show --query tenantId -o tsv
Ok "Tenant: $TenantId"

# --- Resource provider registrations (idempotent; register only if needed) ---
Info "Registering resource providers"
foreach ($ns in $Providers) {
    $state = az provider show --namespace $ns --query registrationState -o tsv 2>$null
    if ($state -ne "Registered") {
        az provider register --namespace $ns | Out-Null
        Ok "$ns — registration requested"
    } else {
        Ok "$ns — already Registered"
    }
}
Info "Waiting for providers to reach 'Registered' (may take several minutes)"
foreach ($ns in $Providers) {
    do {
        $state = az provider show --namespace $ns --query registrationState -o tsv
        if ($state -ne "Registered") { Start-Sleep -Seconds 15 }
    } while ($state -ne "Registered")
    Ok "$ns — Registered"
}

# --- Application resource group ---
Info "Application resource group: $AppResourceGroup"
az group create --name $AppResourceGroup --location $Location | Out-Null
Ok "ready"

# --- Managed identity (create if absent) ---
Info "Managed identity: $IdentityName"
$exists = az identity show -g $AppResourceGroup -n $IdentityName --query id -o tsv 2>$null
if (-not $exists) {
    az identity create --name $IdentityName --resource-group $AppResourceGroup --location $Location | Out-Null
    Ok "created"
} else {
    Ok "already exists"
}
$ClientId    = az identity show -g $AppResourceGroup -n $IdentityName --query clientId   -o tsv
$PrincipalId = az identity show -g $AppResourceGroup -n $IdentityName --query principalId -o tsv
Ok "clientId=$ClientId principalId=$PrincipalId"

# --- Federated credential (main only) ---
Info "Federated credential: $FederatedCredName ($Subject)"
$fcExists = az identity federated-credential show `
    --name $FederatedCredName --identity-name $IdentityName --resource-group $AppResourceGroup `
    --query id -o tsv 2>$null
if (-not $fcExists) {
    az identity federated-credential create `
        --name $FederatedCredName --identity-name $IdentityName --resource-group $AppResourceGroup `
        --issuer $Issuer --subject $Subject --audiences $Audience | Out-Null
    Ok "created"
} else {
    Ok "already exists"
}

# --- State backend: separate RG + storage account + container ---
Info "State resource group: $StateResourceGroup"
az group create --name $StateResourceGroup --location $Location | Out-Null
Ok "ready"

if (-not $StateStorageAccount) {
    # Generate a globally-unique, valid (lowercase alphanumeric, <=24 char) name.
    $StateStorageAccount = "hnotestf{0}" -f (Get-Random -Minimum 100000 -Maximum 999999)
    Info "Generated state storage account name: $StateStorageAccount"
} else {
    Info "Using provided state storage account: $StateStorageAccount"
}

$saExists = az storage account show --name $StateStorageAccount --resource-group $StateResourceGroup --query id -o tsv 2>$null
if (-not $saExists) {
    az storage account create `
        --name $StateStorageAccount --resource-group $StateResourceGroup --location $Location `
        --sku Standard_LRS --encryption-services blob --min-tls-version TLS1_2 | Out-Null
    Ok "storage account created"
} else {
    Ok "storage account already exists"
}

# Container (auth-mode login uses the caller's identity).
$containerExists = az storage container exists `
    --name $StateContainer --account-name $StateStorageAccount --auth-mode login --query exists -o tsv 2>$null
if ($containerExists -ne "true") {
    az storage container create --name $StateContainer --account-name $StateStorageAccount --auth-mode login | Out-Null
    Ok "container '$StateContainer' created"
} else {
    Ok "container '$StateContainer' already exists"
}

# --- Role assignments (idempotent: az returns the existing assignment if present) ---
$SubScope   = "/subscriptions/$SubscriptionId"
$AppRgScope = "$SubScope/resourceGroups/$AppResourceGroup"
$SaScope    = "$SubScope/resourceGroups/$StateResourceGroup/providers/Microsoft.Storage/storageAccounts/$StateStorageAccount"

function Assign-Role($role, $scope) {
    Info "Role assignment: '$role' on $scope"
    az role assignment create `
        --assignee-object-id $PrincipalId --assignee-principal-type ServicePrincipal `
        --role $role --scope $scope 2>$null | Out-Null
    Ok "ensured"
}
Assign-Role "Contributor"                       $AppRgScope
Assign-Role "Role Based Access Control Administrator" $AppRgScope
Assign-Role "Storage Blob Data Contributor"     $SaScope

# --- GitHub secrets (optional; needs `gh auth login`) ---
if ($SetGitHubSecrets) {
    Info "Setting GitHub Actions secrets on $GitHubRepo via gh"
    gh secret set AZURE_CLIENT_ID       --repo $GitHubRepo --body $ClientId
    gh secret set AZURE_TENANT_ID       --repo $GitHubRepo --body $TenantId
    gh secret set AZURE_SUBSCRIPTION_ID --repo $GitHubRepo --body $SubscriptionId
    Ok "secrets set"
}

# --- Summary ---
Write-Host ""
Write-Host "================ BOOTSTRAP COMPLETE ================" -ForegroundColor Green
Write-Host "Set these as GitHub Actions secrets (repo: $GitHubRepo):"
Write-Host "  AZURE_CLIENT_ID       = $ClientId"
Write-Host "  AZURE_TENANT_ID       = $TenantId"
Write-Host "  AZURE_SUBSCRIPTION_ID = $SubscriptionId"
Write-Host ""
Write-Host "Wire these into the Terraform backend block in infra/providers.tf:"
Write-Host "  resource_group_name  = `"$StateResourceGroup`""
Write-Host "  storage_account_name = `"$StateStorageAccount`""
Write-Host "  container_name       = `"$StateContainer`""
Write-Host "  key                  = `"housing-notes.tfstate`""
Write-Host "===================================================" -ForegroundColor Green
