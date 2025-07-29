#!/usr/bin/env bash

# Bootstraps the resources etc for a Fabric Admin  environment deployed via Terraform
# App reg, Entra group, Storage Account, Managed Identity

# Load common functions
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib/common.sh"

# Check prerequisites
check_prerequisites "bootstrap"

# Get subscription information
get_subscription_info

domain=$(az account show --query tenantDefaultDomain -otsv 2>/dev/null)
tenant_id=$(az account show --query tenantId -otsv 2>/dev/null)

# Validate domain and tenant_id
[[ -n "$domain" ]] || error "Failed to retrieve tenant domain."
[[ -n "$tenant_id" ]] || error "Failed to retrieve tenant ID."

# Parse options
parse_options "bootstrap" "$@"

# Set default values
set_defaults "bootstrap"

echo ""
echo "=== BOOTSTRAP SUMMARY ==="
echo ""
echo "Tenant Domain:           $domain"
echo "Tenant ID:               $tenant_id"
echo "Security Group:          Microsoft Fabric Workload Identities"
echo ""
echo "Management Subscription: $management_subscription_id"
echo "Resource Group:          $rg"
echo "Storage Account:         (to be created)"
echo "Managed Identity:        $managed_identity_name"
echo ""
echo "Workload Subscription:   $workload_subscription_id"
echo "Role                     $workload_subscription_rbac_role"
echo ""
read -p "Proceed with these settings? (Y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted by user."
    exit 1
fi

########################################################################
## Create Resource Group
########################################################################


# Set the subscription for management operations
echo -n "Setting subscription context to $management_subscription_id... "
az account set --subscription "$management_subscription_id"
[[ $? -eq 0 ]] && echo "done." || error "Failed to set subscription context."

# Create resource group if it doesn't exist
echo -n "Creating resource group $rg in $location... "
az group create --name "$rg" --location "$location" >/dev/null
[[ $? -eq 0 ]] && echo "done." || error "Failed to create resource group."

########################################################################
## Create Storage Account for Terraform State Remote Backend
########################################################################

echo "Creating storage account for Terraform state remote backend..."

# Generate a unique storage account name
storage_account_name="terraformfabric$(az group show --name "$rg"  --query id -otsv | sha1sum | cut -c1-8)"
echo "Storage account name: $storage_account_name"

# Create storage account with secure settings
echo -n "Creating storage account... "
az storage account create \
    --name "$storage_account_name" \
    --resource-group "$rg" \
    --location "$location" \
    --min-tls-version TLS1_2 \
    --sku Standard_LRS \
    --https-only true \
    --default-action "Allow" \
    --public-network-access "Enabled" \
    --allow-shared-key-access false \
    --allow-blob-public-access false >/dev/null
[[ $? -eq 0 ]] && echo "done." || error "Failed to create storage account."

# Get storage account resource ID
storage_account_id=$(az storage account show --name "$storage_account_name" --resource-group "$rg" --query id -otsv)
[[ -n "$storage_account_id" ]] || error "Failed to retrieve storage account resource ID."

########################################################################
## Create Managed Identity for Terraform Automation
########################################################################

echo "Creating Managed Identity for Terraform..."

echo -n "Creating managed identity $managed_identity_name... "
az identity create --name $managed_identity_name --resource-group $rg --location $location >/dev/null
[[ $? -eq 0 ]] && echo "done." || error "Failed to create managed identity."

managed_identity_object_id=$(az identity show --name $managed_identity_name --resource-group $rg --query principalId -otsv)
managed_identity_client_id=$(az identity show --name $managed_identity_name --resource-group $rg --query clientId -otsv)

[[ -n "$managed_identity_object_id" ]] || error "Failed to retrieve managed identity object ID."
[[ -n "$managed_identity_client_id" ]] || error "Failed to retrieve managed identity client ID."

echo "Managed identity created - Object ID: $managed_identity_object_id"

########################################################################
## Create Entra group and add into Fabric tenant settings
########################################################################

echo "Creating Entra security group for Fabric workload identities..."

# Hardcoded values for the Entra security group
fabric_group_name="Microsoft Fabric Workload Identities"
fabric_group_description="Service Principals and Managed Identities used for Fabric automation."
fabric_group_mail_nickname="FabricWorkloadIdentities"

echo -n "Creating security group $fabric_group_name... "
az ad group create --display-name "$fabric_group_name" --description "$fabric_group_description" --mail-nickname "$fabric_group_mail_nickname" >/dev/null
if [[ $? -eq 0 ]]; then
    echo "done."
else
    # Group might already exist, check if we can retrieve it
    fabric_group_id=$(az ad group show --group "$fabric_group_name" --query id -otsv 2>/dev/null)
    if [[ -n "$fabric_group_id" ]]; then
        echo "already exists."
    else
        error "Failed to create or find security group."
    fi
fi

# Get the group ID (whether newly created or existing)
if [[ -z "$fabric_group_id" ]]; then
    fabric_group_id=$(az ad group show --group "$fabric_group_name" --query id -otsv)
    [[ -n "$fabric_group_id" ]] || error "Failed to retrieve security group ID."
fi

echo "Security group ID: $fabric_group_id"

########################################################################
## Update storage account properties
########################################################################

echo "Updating storage account properties..."
# Enable blob versioning and retention
echo -n "Enabling blob versioning and retention... "
az storage account blob-service-properties update \
    --account-name "$storage_account_name" \
    --enable-versioning true \
    --enable-delete-retention true \
    --delete-retention-days 7 >/dev/null
[[ $? -eq 0 ]] && echo "done." || error "Failed to update blob service properties."

# Create containers for prod and dev
echo -n "Creating prod container... "
az storage container create --name prod --account-name "$storage_account_name" --auth-mode login >/dev/null
[[ $? -eq 0 ]] && echo "done." || error "Failed to create prod container."

echo -n "Creating dev container... "
az storage container create --name dev --account-name "$storage_account_name" --auth-mode login >/dev/null
[[ $? -eq 0 ]] && echo "done." || error "Failed to create dev container."

# Assign Storage Blob Data Contributor role to the signed-in user for the dev container
echo -n "Assigning Storage Blob Data Contributor role to current user for dev container... "
az role assignment create \
    --assignee "$(az ad signed-in-user show --query id -otsv)" \
    --scope "$storage_account_id/blobServices/default/containers/dev" \
    --role "Storage Blob Data Contributor" >/dev/null
[[ $? -eq 0 ]] && echo "done." || error "Failed to assign role to current user."

echo "Storage account updated and containers created."

########################################################################
## Configure Fabric tenant settings for service principal access
########################################################################

echo "Adding Entra security group to Fabric tenant settings..."

body=$(jq -nc --arg oid "$fabric_group_id" --arg name "$fabric_group_name" '{"enabled":true,"canSpecifySecurityGroups":true,"enabledSecurityGroups":[{"graphId":$oid,"name":$name}]}')
echo "Tenant setting payload:"
jq . <<< "$body"

sleep 1
echo -n " - ServicePrincipalAccessPermissionAPIs... "
fab api --method post admin/tenantsettings/ServicePrincipalAccessPermissionAPIs/update -i "$body" >/dev/null
[[ $? -eq 0 ]] && echo "done." || echo "failed (may already be configured)."

sleep 1
echo -n " - ServicePrincipalAccessGlobalAPIs... "
fab api --method post admin/tenantsettings/ServicePrincipalAccessGlobalAPIs/update -i "$body" >/dev/null
[[ $? -eq 0 ]] && echo "done." || echo "failed (may already be configured)."

sleep 1
echo -n " - AllowServicePrincipalsCreateAndUseProfiles... "
fab api --method post admin/tenantsettings/AllowServicePrincipalsCreateAndUseProfiles/update -i "$body" >/dev/null
[[ $? -eq 0 ]] && echo "done." || echo "failed (may already be configured)."

echo "Verifying tenant settings:"
fab api --method get admin/tenantsettings --query "text.tenantSettings[?tenantSettingGroup == 'Developer settings']" | jq .

echo "Entra security group added to Fabric tenant settings."

########################################################################
## Managed identity role assignments, app roles, and group membership
########################################################################

echo "Assigning Storage Blob Data Contributor role to managed identity for prod container..."
az role assignment create \
    --assignee $managed_identity_object_id \
    --scope "$storage_account_id/blobServices/default/containers/prod" \
    --role "Storage Blob Data Contributor" >/dev/null
[[ $? -eq 0 ]] && echo "Role assignment completed." || error "Failed to assign storage role to managed identity."

if [[ -n "$workload_subscription_rbac_role" ]]; then
    echo "Assigning role '$workload_subscription_rbac_role' to managed identity in subscription $workload_subscription_id..."

    az role assignment create \
        --assignee "$managed_identity_object_id" \
        --scope "/subscriptions/$workload_subscription_id" \
        --role "$workload_subscription_rbac_role" >/dev/null
    [[ $? -eq 0 ]] && echo "Subscription role assignment completed." || echo "Warning: Failed to assign subscription role (may already exist or insufficient permissions)."
fi

echo "Assigning app roles to managed identity in Microsoft Graph..."
graph_app_id="00000003-0000-0000-c000-000000000000"
graph_object_id=$(az ad sp show --id "$graph_app_id" --query id -otsv 2>/dev/null)
[[ -n "$graph_object_id" ]] || error "Failed to retrieve Microsoft Graph service principal object ID."

for role in User.Read.All Group.Read.All
do
  echo -n "  Adding app role $role... "
  app_role_id=$(az ad sp show --id $graph_app_id --query "appRoles[?value == '"$role"'].id" -otsv 2>/dev/null)

  if [[ -z "$app_role_id" ]]; then
    echo "failed (role not found)."
    continue
  fi

  body=$(jq -nc --arg graph "$graph_object_id" --arg mi "$managed_identity_object_id" --arg role "$app_role_id" '{principalId:$mi,resourceId:$graph,appRoleId:$role}')

  az rest --method post --uri "https://graph.microsoft.com/v1.0/servicePrincipals/${managed_identity_object_id}/appRoleAssignments" --body "$body" >/dev/null 2>&1
  [[ $? -eq 0 ]] && echo "done." || echo "failed (may already exist)."
done

echo -n "Adding managed identity to Entra security group $fabric_group_name... "
az ad group member add --group "$fabric_group_name" --member-id "$managed_identity_object_id" >/dev/null 2>&1
[[ $? -eq 0 ]] && echo "done." || echo "failed (may already be a member)."

########################################################################

echo "Bootstrap completed successfully!"

# Validate final state
echo "Validating final configuration..."

echo ""
echo "=== BOOTSTRAP SUMMARY ==="
echo "Tenant Domain:           $domain"
echo "Tenant ID:               $tenant_id"
echo "Security Group:          $fabric_group_name"
echo ""
echo "Management Subscription: $management_subscription_id"
echo "Resource Group:          $rg"
echo "Storage Account:         $storage_account_name"
echo "Managed Identity:        $managed_identity_name"
echo ""
echo "Workload Subscription:   $workload_subscription_id"
echo "Role:                    $workload_subscription_rbac_role"
echo ""
echo "=== USEFUL LINKS ==="
echo "Azure Portal:  https://portal.azure.com/#@${domain}/resource/subscriptions/${management_subscription_id}/resourceGroups/${rg}/overview"
echo "Entra Groups:  https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupDetailsMenuBlade/~/Members/groupId/${fabric_group_id}/menuId/"
echo "Fabric Admin:  https://app.powerbi.com/admin-portal/tenantSettings?${tenant_id}&experience=fabric-developer"