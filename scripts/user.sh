#!/usr/bin/env bash

########################################################################
## Create App Reg for Microsoft Fabric Terraform Provider's user context
########################################################################

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

tenant_id=$(az account show --query tenantId -otsv)
[[ -z "$tenant_id" ]] && error "Failed to retrieve tenant ID. Please ensure you are logged in to Azure CLI."

echo "Creating App Registration for Microsoft Fabric Terraform Provider's user context..."

app_name="fabric_terraform_provider"
identifier_uri="api://$tenant_id/$app_name"

# Create the app registration
az ad app create --display-name "$app_name" --identifier-uris "$identifier_uri"
[[ $? -ne 0 ]] && error "Failed to create app registration."

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

echo -n "Setting required resource accesses... "
az ad app update --id "$identifier_uri" --required-resource-accesses "$required_resource_accesses"
[[ $? -ne 0 ]] && error "Failed to set required resource accesses."
echo "done."

# Expose the API
exposed_api='{
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
    "preAuthorizedApplications": [],
    "requestedAccessTokenVersion": null
}'
echo -n "Exposing the API... "
az ad app update --id "$identifier_uri" --set api="$exposed_api"
[[ $? -ne 0 ]] && error "Failed to expose the API."
echo "done."

# Pre-authorize applications
app_authorizations='{
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
        {
            "appId": "871c010f-5e61-4fb1-83ac-98610a7e9110",
            "delegatedPermissionIds": [
                "1ca1271c-e2c0-437c-af9a-3a92e745a24d"
            ]
        },
        {
            "appId": "00000009-0000-0000-c000-000000000000",
            "delegatedPermissionIds": [
                "1ca1271c-e2c0-437c-af9a-3a92e745a24d"
            ]
        },
        {
            "appId": "1950a258-227b-4e31-a9cf-717495945fc2",
            "delegatedPermissionIds": [
                "1ca1271c-e2c0-437c-af9a-3a92e745a24d"
            ]
        },
        {
            "appId": "04b07795-8ddb-461a-bbee-02f9e1bf7b46",
            "delegatedPermissionIds": [
                "1ca1271c-e2c0-437c-af9a-3a92e745a24d"
            ]
        }
    ],
    "requestedAccessTokenVersion": null
}'

echo -n "Pre-authorizing applications (PowerBI, Azure CLI, PowerShell)... "
az ad app update --id "$identifier_uri" --set api="$app_authorizations"
[[ $? -ne 0 ]] && error "Failed to pre-authorize applications."
echo "done."


# Add the signed-in user as owner
owner_id=$(az ad signed-in-user show --query id -otsv)
echo -n "Adding you as owner... "
az ad app owner add --id "$identifier_uri" --owner-object-id "$owner_id"
[[ $? -ne 0 ]] && error "Failed to add owner. Please check your Azure CLI configuration."
echo "done."

# Show the created app registration
az ad app show --id "$identifier_uri" --output jsonc

echo "App Registration created. Authenticate with:"
echo "az login --scope $identifier_uri/.default"
