#!/usr/bin/env bash

#!/usr/bin/env bash

# Bootstraps the resources etc for a Fabric Admin  environment deployed via Terraform
# App reg, Entra group, Storage Account, Managed Identity

# Load common functions
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/../lib/common.sh"

# Check prerequisites
check_prerequisites "github"

# Get subscription information
get_subscription_info

tenant_id=$(az account show --query tenantId -otsv)

# Get organization and repo name using GitHub CLI
repo_info=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) || error "Unable to get repository info from GitHub CLI."

# Split organization and repo name
org="${repo_info%%/*}"
repo="${repo_info##*/}"

# Parse options
parse_options "github" "$@"

# Set default values
set_defaults "github"

managed_identity_client_id=$(az identity show --name $managed_identity_name --resource-group $rg --query clientId -otsv)
storage_account_name="terraformfabric$(az group show --name "$rg"  --query id -otsv | sha1sum | cut -c1-8)"

echo ""
echo "=== GITHUB SUMMARY ==="
echo ""
echo "GitHub Organization/User: $org"
echo "GitHub Repository:        $repo"
echo ""
echo "Azure Tenant ID:          $tenant_id"
echo "Management Subscription:  $management_subscription_id"
echo "Resource Group:           $rg"
echo "Managed Identity:         $managed_identity_name"
echo "Storage Account Name:     $storage_account_name"
echo ""
echo "Workload Subscription:    $workload_subscription_id"
echo ""
read -p "Proceed to remove GitHub variables and federated credential? (Y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted by user."
    exit 1
fi

echo -e "\nDeleting GitHub Actions variables..."

gh variable delete ARM_TENANT_ID
gh variable delete ARM_CLIENT_ID
gh variable delete ARM_SUBSCRIPTION_ID
gh variable delete BACKEND_AZURE_SUBSCRIPTION_ID
gh variable delete BACKEND_AZURE_RESOURCE_GROUP_NAME
gh variable delete BACKEND_AZURE_STORAGE_ACCOUNT_NAME
gh variable delete BACKEND_AZURE_STORAGE_ACCOUNT_CONTAINER_NAME
gh variable delete TFVARS_FILE
echo "Done."

echo -en "\nDeleting federated credential for GitHub Actions on the managed identity... "
subject=$(gh repo view --json nameWithOwner --template '{{printf "repo:%s:ref:refs/heads/main" .nameWithOwner}}')
az identity federated-credential delete --name github --identity-name $managed_identity_name --resource-group $rg --yes
echo "done."