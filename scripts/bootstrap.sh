#!/usr/bin/env bash

# Bootstraps the resources etc for a Fabric Admin  environment deployed via Terraform
# App reg, Entra group, Storage Account, Managed Identity

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Bootstraps the resources required for a Fabric Admin environment deployed via Terraform.
Creates an App Registration, Entra security group, Storage Account, and Managed Identity.

OPTIONS:
    -g, --resource-group <name>    Resource group name (required)
    -i, --identity <name>          Managed identity name (default: mi-terraform)
    -l, --location <region>        Azure region (default: $AZURE_DEFAULTS_LOCATION or uksouth)
    -m, --management-subscription-id <id>  Management subscription ID (default: current subscription)
    -r, --role <role_name>         RBAC role to assign to managed identity on workload subscription (default: Reader)
    -s, --subscription-id <id>     Workload subscription ID (default: current subscription)
    -h, --help, -?                 Show this help message and exit

EXAMPLES:
    $0                                                                        # Use defaults
    $0 -g my-rg -l eastus                                                     # Custom resource group and location
    $0 --resource-group my-rg --location eastus                               # Using long options
    $0 -g my-rg --role "Contributor" --subscription-id "12345678-..."         # Assign Contributor role
    $0 -g my-rg --identity mi-tf --management-subscription-id "87654321-..."  # Custom identity and management subscription

PREREQUISITES:
    - Azure CLI installed and logged in (az login)
    - Microsoft Fabric CLI installed and logged in (fab auth login)
    - jq installed (recommended)
    - Fabric Administrator role in your tenant

The script will create:
    1. App Registration for Fabric Terraform Provider
    2. Storage Account for Terraform state backend
    3. Entra security group for Fabric workload identities
    4. Managed Identity for Terraform automation
    5. Configure Fabric tenant settings for service principal access

EOF
    exit 0
}

error() {
    echo "Error: $1" >&2
    exit 1
}

# Check for Azure CLI
command -v az >/dev/null 2>&1 || error "Azure CLI (az) is not installed."

# Check for required Azure login
az account show >/dev/null 2>&1 || error "Not logged in to Azure CLI. Please run 'az login'."

# Check for jq (used for JSON parsing if needed)
command -v jq >/dev/null 2>&1 || echo "Warning: jq not found. Some features may not work as expected."

subscription_id=$(az account show --query id -otsv)

# Validate subscription_id is a non-empty GUID
if ! [[ "$subscription_id" =~ ^[0-9a-fA-F-]{36}$ ]]; then
    error "Not logged in to Azure CLI or invalid subscription ID."
fi

# Parse options
while getopts ":g:i:l:m:r:s:h?-:" opt; do
    case $opt in
        g) rg="$OPTARG"
        ;;
        i) managed_identity_name="$OPTARG"
        ;;
        l) location="$OPTARG"
        ;;
        m) management_subscription_id="$OPTARG"
        ;;
        r) workload_subscription_rbac_role="$OPTARG"
        ;;
        s) workload_subscription_id="$OPTARG"
        ;;
        h|?) usage
        ;;
        -) case "${OPTARG}" in
            help) usage
            ;;
            resource-group) rg="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
            ;;
            resource-group=*) rg="${OPTARG#*=}"
            ;;
            location) location="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
            ;;
            location=*) location="${OPTARG#*=}"
            ;;
            identity) managed_identity_name="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
            ;;
            identity=*) managed_identity_name="${OPTARG#*=}"
            ;;
            management-subscription-id) management_subscription_id="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
            ;;
            management-subscription-id=*) management_subscription_id="${OPTARG#*=}"
            ;;
            role) workload_subscription_rbac_role="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
            ;;
            role=*) workload_subscription_rbac_role="${OPTARG#*=}"
            ;;
            subscription-id) workload_subscription_id="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
            ;;
            subscription-id=*) workload_subscription_id="${OPTARG#*=}"
            ;;
            *) echo "Invalid option --$OPTARG" >&2; exit 1
            ;;
           esac
        ;;
        \?) echo "Invalid option -$OPTARG" >&2; exit 1
        ;;
    esac
done

# Set default values for management_subscription_id and workload_subscription_id if not specified
rg="${rg:-rg-terraform}"
managed_identity_name="${managed_identity_name:-mi-terraform}"
location="${location:-${AZURE_DEFAULTS_LOCATION:-uksouth}}"
management_subscription_id="${management_subscription_id:-$subscription_id}"
workload_subscription_id="${workload_subscription_id:-$subscription_id}"
workload_subscription_rbac_role="${workload_subscription_rbac_role:-Reader}"



########################################################################
## Create Resource Group
########################################################################


# Set the subscription for management operations
az account set --subscription "$management_subscription_id"

# Create resource group if it doesn't exist
echo "Creating resource group $rg..."
az group create --name "$rg" --location "$location"

########################################################################
## Create Storage Account for Terraform State Remote Backend
########################################################################

echo "Creating storage account for Terraform state remote backend..."

# Generate a unique storage account name
storage_account_name="terraformfabric$(az group show --name "$rg"  --query id -otsv | sha1sum | cut -c1-8)"

# Create storage account with secure settings
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
    --allow-blob-public-access false

# Get storage account resource ID
storage_account_id=$(az storage account show --name "$storage_account_name" --resource-group "$rg" --query id -otsv)

########################################################################
## Create Managed Identity for Terraform Automation
########################################################################

echo "Creating Managed Identity for Terraform..."

az identity create --name $managed_identity_name --resource-group $rg --location $location
managed_identity_object_id=$(az identity show --name $managed_identity_name --resource-group $rg --query principalId -otsv)
managed_identity_client_id=$(az identity show --name $managed_identity_name --resource-group $rg --query clientId -otsv)

########################################################################
## Create Entra group and add into Fabric tenant settings
########################################################################

echo "Creating Entra security group for Fabric workload identities..."

# Hardcoded values for the Entra security group
fabric_group_name="Microsoft Fabric Workload Identities"
fabric_group_description="Service Principals and Managed Identities used for Fabric automation."
fabric_group_mail_nickname="FabricWorkloadIdentities"

az ad group create --display-name "$fabric_group_name" --description "$fabric_group_description" --mail-nickname "$fabric_group_mail_nickname"

fabric_group_id=$(az ad group show --group "$fabric_group_name" --query id -otsv)
echo "Created security group $fabric_group_name"

########################################################################
## Update storage account properties
########################################################################

echo "Updating storage account properties..."
# Enable blob versioning and retention
az storage account blob-service-properties update \
    --account-name "$storage_account_name" \
    --enable-versioning true \
    --enable-delete-retention true \
    --delete-retention-days 7

# Create containers for prod and dev
az storage container create --name prod --account-name "$storage_account_name" --auth-mode login
az storage container create --name dev --account-name "$storage_account_name" --auth-mode login

# Assign Storage Blob Data Contributor role to the signed-in user for the dev container
az role assignment create \
    --assignee "$(az ad signed-in-user show --query id -otsv)" \
    --scope "$storage_account_id/blobServices/default/containers/dev" \
    --role "Storage Blob Data Contributor"

echo "Storage account updated and containers created."

########################################################################
## Configure Fabric tenant settings for service principal access
########################################################################

echo "Adding Entra security group to Fabric tenant settings..."

body=$(jq -nc --arg oid "$fabric_group_id" --arg name "$fabric_group_name" '{"enabled":true,"canSpecifySecurityGroups":true,"enabledSecurityGroups":[{"graphId":$oid,"name":$name}]}')
jq . <<< "$body"

sleep 1
echo " - ServicePrincipalAccessPermissionAPIs"
fab api --method post admin/tenantsettings/ServicePrincipalAccessPermissionAPIs/update -i "$body"
sleep 1
echo " - ServicePrincipalAccessGlobalAPIs"
fab api --method post admin/tenantsettings/ServicePrincipalAccessGlobalAPIs/update -i "$body"
sleep 1
echo " - AllowServicePrincipalsCreateAndUseProfiles"
fab api --method post admin/tenantsettings/AllowServicePrincipalsCreateAndUseProfiles/update -i "$body"

fab api --method get admin/tenantsettings --query "text.tenantSettings[?tenantSettingGroup == 'Developer settings']" | jq .

echo "Entra security group added to Fabric tenant settings."

########################################################################
## Managed identity role assignments, app roles, and group membership
########################################################################

echo "Assigning Storage Blob Data Contributor role to managed identity for prod container..."
az role assignment create \
    --assignee $managed_identity_object_id \
    --scope "$storage_account_id/blobServices/default/containers/prod" \
    --role "Storage Blob Data Contributor"


if [[ -n "$workload_subscription_rbac_role" ]]; then
    echo "Assigning role '$workload_subscription_rbac_role' to managed identity in subscription $workload_subscription_id..."

    az role assignment create \
        --assignee "$managed_identity_object_id" \
        --scope "/subscriptions/$workload_subscription_id" \
        --role "$workload_subscription_rbac_role"
fi

echo "Assigning app roles to managed identity in Microsoft Graph..."
graph_app_id="00000003-0000-0000-c000-000000000000"
graph_object_id=$(az ad sp show --id "00000003-0000-0000-c000-000000000000" --query id -otsv)

for role in User.Read.All Group.Read.All
do
  app_role_id=$(az ad sp show --id $graph_app_id --query "appRoles[?value == '"$role"'].id" -otsv)
  body=$(jq -nc --arg graph "$graph_object_id" --arg mi "$managed_identity_object_id" --arg role "$app_role_id" '{principalId:$mi,resourceId:$graph,appRoleId:$role}')
  echo "Adding app role $role:"
  jq . <<< $body
  az rest --method post --uri "https://graph.microsoft.com/v1.0/servicePrincipals/${managed_identity_object_id}/appRoleAssignments" --body "$body"
done

echo -n "Adding managed identity to Entra security group $fabric_group_name... "
az ad group member add --group "$fabric_group_name" --member-id "$managed_identity_object_id"
echo "done.

########################################################################