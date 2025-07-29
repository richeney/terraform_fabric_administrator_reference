#!/usr/bin/env bash

# Generates a Terraform backend configuration file for Azure Remote State
# Creates a backend.tf file with the Azure storage backend configuration

# Load common functions
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib/common.sh"

# Check prerequisites
check_prerequisites "backend"

# Get subscription information
get_subscription_info

# Parse options
parse_options "backend" "$@"

# Set default values
set_defaults "backend"

# Find the repository root
repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || error "Not in a git repository or unable to find repository root."

# Calculate storage account name using the same logic as bootstrap/github scripts
storage_account_name="terraformfabric$(az group show --name "$rg" --query id -otsv | sha1sum | cut -c1-8)"

# Verify the storage account exists
echo "Checking if storage account exists..."
if ! az storage account show --name "$storage_account_name" --resource-group "$rg" >/dev/null 2>&1; then
    error "Storage account '$storage_account_name' does not exist in resource group '$rg'. Please run bootstrap.sh first."
fi

echo ""
echo "=== BACKEND CONFIGURATION SUMMARY ==="
echo ""
echo "Repository Root:          $repo_root"
echo "Management Subscription:  $management_subscription_id"
echo "Resource Group:           $rg"
echo "Storage Account:          $storage_account_name"
echo "Container Name:           $container_name"
echo "State Key:                $state_key"
echo ""
echo "The backend.tf file will be created in: $repo_root/backend.tf"
echo ""
read -p "Proceed with generating backend.tf? (Y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted by user."
    exit 1
fi

echo ""
echo "Generating backend.tf in repository root: $repo_root"

# Change to repository root and create the backend.tf file
cd "$repo_root" || error "Unable to change to repository root directory."

# Check if backend.tf already exists
if [[ -f "backend.tf" ]]; then
    echo ""
    echo "ℹ️  backend.tf already exists in the repository root."

    # Generate the new content to compare
    new_content="terraform {
  backend \"azurerm\" {
    subscription_id      = \"$management_subscription_id\"
    resource_group_name  = \"$rg\"
    storage_account_name = \"$storage_account_name\"
    container_name       = \"$container_name\"
    key                  = \"$state_key\"
    use_azuread_auth     = true
  }
}"

    # Compare existing content with new content
    if [[ "$(cat backend.tf)" == "$new_content" ]]; then
        echo "✅ The existing backend.tf file already contains the correct configuration."
        echo "No changes needed. The file remains unchanged."
        exit 0
    fi

    echo "Current content preview:"
    echo "========================"
    head -10 backend.tf | sed 's/^/  /'
    echo "========================"
    echo ""
    read -p "Do you want to overwrite the existing backend.tf file? (Y/N): " overwrite_confirm
    if [[ ! "$overwrite_confirm" =~ ^[Yy]$ ]]; then
        echo "Operation cancelled. Existing backend.tf file was not modified."
        exit 0
    fi
    echo ""
    echo "Overwriting existing backend.tf file..."
fi

cat > backend.tf <<BACKEND
terraform {
  backend "azurerm" {
    subscription_id      = "$management_subscription_id"
    resource_group_name  = "$rg"
    storage_account_name = "$storage_account_name"
    container_name       = "$container_name"
    key                  = "$state_key"
    use_azuread_auth     = true
  }
}
BACKEND

echo "✅ backend.tf file created successfully!"
echo ""
echo "The backend configuration has been written to '$repo_root/backend.tf'."
echo "You can now run 'terraform init' from the repository root to initialize the Terraform backend."
echo ""
echo "Note: Ensure you have appropriate permissions to access the storage account"
echo "      and that the container '$container_name' exists in the storage account."
