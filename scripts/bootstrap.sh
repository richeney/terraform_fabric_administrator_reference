#!/usr/bin/env bash

# Bootstraps the resources etc for a Fabric Admin  environment deployed via Terraform
# App reg, Entra group, Storage Account, Managed Identity

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
while getopts ":g:l:" opt; do
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
        \?) echo "Invalid option -$OPTARG" >&2; exit 1
        ;;
    esac
done

# Set default values for management_subscription_id and workload_subscription_id if not specified
rg="${rg:-rg-terraform}"
managed_identity_name="${managed_identity_name:-mi-terraform}"
location="${location:-uksouth}"
management_subscription_id="${management_subscription_id:-$subscription_id}"
workload_subscription_id="${workload_subscription_id:-$subscription_id}"
workload_subscription_rbac_role="${workload_subscription_rbac_role:-""}"

########################################################################
## Create App Reg for Microsoft Fabric Terraform Provider's user context
########################################################################


echo "Creating App Registration for Microsoft Fabric Terraform Provider's user context..."

app_name="fabric_terraform_provider"
identifier_uri="api://$app_name"

# Create the app registration
az ad app create --display-name "$app_name" --identifier-uris "$identifier_uri"

# Set required resource accesses
required_resource_accesses='[
    {
        "resourceAppId": "00000003-0000-0000-c000-000000000000",
        "resourceAccess": [
            {"id": "e1fe6dd8-ba31-4d61-89e7-88639da4683d", "type": "Scope"},
            {"id": "b340eb25-3456-403f-be2f-af7a0d370277", "type": "Scope"}
        ]
    },
    {
        "resourceAppId": "00000009-0000-0000-c000-000000000000",
        "resourceAccess": [
            {"id": "4eabc3d1-b762-40ff-9da5-0e18fdf11230", "type": "Scope"},
            {"id": "b2f1b2fa-f35c-407c-979c-a858a808ba85", "type": "Scope"},
            {"id": "445002fb-a6f2-4dc1-a81e-4254a111cd29", "type": "Scope"},
            {"id": "8b01a991-5a5a-47f8-91a2-84d6bfd72c02", "type": "Scope"}
        ]
    }
]'
az ad app update --id "$identifier_uri" --required-resource-accesses "$required_resource_accesses"

# Set API permissions and pre-authorized applications
api_permissions='{
    "acceptMappedClaims": null,
    "knownClientApplications": [],
    "oauth2PermissionScopes": [
        {
            "adminConsentDescription": "Allows connection to backend services for Microsoft Fabric Terraform Provider",
            "adminConsentDisplayName": "Microsoft Fabric Terraform Provider",
            "id": "1ca1271c-e2c0-437c-af9a-3a92e745a24d",
            "isEnabled": true,
            "type": "User",
            "userConsentDescription": "Allows connection to backend services for Microsoft Fabric Terraform Provider",
            "userConsentDisplayName": "Microsoft Fabric Terraform Provider",
            "value": "access"
        }
    ],
    "preAuthorizedApplications": [
        {"appId": "871c010f-5e61-4fb1-83ac-98610a7e9110", "delegatedPermissionIds": ["1ca1271c-e2c0-437c-af9a-3a92e745a24d"]},
        {"appId": "00000009-0000-0000-c000-000000000000", "delegatedPermissionIds": ["1ca1271c-e2c0-437c-af9a-3a92e745a24d"]},
        {"appId": "1950a258-227b-4e31-a9cf-717495945fc2", "delegatedPermissionIds": ["1ca1271c-e2c0-437c-af9a-3a92e745a24d"]},
        {"appId": "04b07795-8ddb-461a-bbee-02f9e1bf7b46", "delegatedPermissionIds": ["1ca1271c-e2c0-437c-af9a-3a92e745a24d"]}
    ],
    "requestedAccessTokenVersion": null
}'
az ad app update --id "$identifier_uri" --set api="$api_permissions"

# Add the signed-in user as owner
owner_id=$(az ad signed-in-user show --query id -otsv)
az ad app owner add --id "$identifier_uri" --owner-object-id "$owner_id"

# Show the created app registration
az ad app show --id "$identifier_uri" --output jsonc

echo "App Registration created."

########################################################################
## Create Storage Account for Terraform State Remote Backend
########################################################################

echo "Creating storage account for Terraform state remote backend..."

# Set the subscription for management operations
az account set --subscription "$management_subscription_id"

# Create resource group if it doesn't exist
az group create --name "$rg" --location "$location"

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

echo "Storage account created."

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

body=$(jq -nc --arg oid "$fabric_group_id" --arg name "$fabric_group_name" '{"enabled":true,"canSpecifySecurityGroups":true,"enabledSecurityGroups":[{"graphId":$oid,"name":$name}]}')
fab api --method post admin/tenantsettings/ServicePrincipalAccessGlobalAPIs/update -i "$body"
fab api --method post admin/tenantsettings/ServicePrincipalAccessPermissionAPIs/update -i "$body"
fab api --method post admin/tenantsettings/AllowServicePrincipalsCreateAndUseProfiles/update -i "$body"

fab api --method get admin/tenantsettings --query "text.tenantSettings[?tenantSettingGroup == 'Developer settings']" | jq .

echo "Entra security group created and added to Fabric tenant settings."

########################################################################
## Create Entra group and add into Fabric tenant settings
########################################################################

echo "Creating Managed Identity for Terraform..."

az identity create --name $managed_identity_name --resource-group $rg --location $location
managed_identity_object_id=$(az identity show --name $managed_identity_name --resource-group $rg --query principalId -otsv)
managed_identity_client_id=$(az identity show --name $managed_identity_name --resource-group $rg --query clientId -otsv)

az role assignment create \
    --assignee $managed_identity_object_id \
    --scope "$storage_account_id/blobServices/default/containers/prod" \
    --role "Storage Blob Data Contributor"

az ad group member add --group "$fabric_group_name" --member-id "$managed_identity_object_id"

# Assign RBAC role if set
if [[ -n "$workload_subscription_rbac_role" ]]; then
    echo "Assigning role '$workload_subscription_rbac_role' to managed identity in subscription $workload_subscription_id..."

    az role assignment create \
        --assignee "$managed_identity_object_id" \
        --scope "/subscriptions/$workload_subscription_id" \
        --role "$workload_subscription_rbac_role"
fi

# Assign Entra app roles

entra_roles="['User.ReadBasic.All','Group.Read.All']"
graph_object_id=$(az ad sp show --id "00000003-0000-0000-c000-000000000000" --query id -otsv)
app_role_ids=$(az ad sp show --id 00000003-0000-0000-c000-000000000000 --query "appRoles[?contains(\`$entra_roles\`, value)].id" -otsv)
for role in $app_role_ids
do
  body=$(jq -nc --arg graph "$graph_object_id" --arg mi "$managed_identity_object_id" --arg role "$role" '{principalId:$mi,resourceId:$graph,appRoleId:$role}')
  az rest --method post --uri "https://graph.microsoft.com/v1.0/servicePrincipals/${managed_identity_object_id}/appRoleAssignments" --body "$body"
done
