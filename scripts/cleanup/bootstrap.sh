#!/usr/bin/env bash
# Assumes defaults

read -r -p "This will reset tenant settings and delete resources. Continue? [Y/n] " response
response=${response,,} # to lowercase
if [[ "$response" =~ ^(n|no)$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

echo "Resetting developer settings in Microsoft Fabric Admin Portal's tenant settings..."
body=$(jq -nc '{"enabled":false,"canSpecifySecurityGroups":false}')
fab api --method post admin/tenantsettings/ServicePrincipalAccessGlobalAPIs/update -i "$body"
fab api --method post admin/tenantsettings/ServicePrincipalAccessPermissionAPIs/update -i "$body"
fab api --method post admin/tenantsettings/AllowServicePrincipalsCreateAndUseProfiles/update -i "$body"

echo "Deleting Entra security group \"Microsoft Fabric Workload Identities\""
az ad group delete --group "Microsoft Fabric Workload Identities"

echo "Deleting resource group \"rg-terraform\""
az group delete --no-wait --name rg-terraform
