# Service Principal with OpenID Connect

Based on <https://registry.terraform.io/providers/microsoft/fabric/latest/docs/guides/auth_app_reg_spn>.

1. Core app reg and service principal

    This script

    - Creates the app reg using the manifest.json file
    - Creates a service principal
    - Adds you as owner to both, which is optional but recommended

    ```shell
    appObjId=$(az ad app create --display-name terraform_fabric_administrator --required-resource-accesses @manifest.json --identifier-uris api://terraform_fabric_administrator --query id -otsv)
    appId=$(az ad app show --id $appObjId --query appId -otsv)
    spObjId=$(az ad sp create --id $appObjId --query id -otsv)
    myObjId=$(az ad signed-in-user show --query id -otsv)
    az ad app owner add --id $appObjId --owner-object-id $myObjId
    az rest --method POST --url "https://graph.microsoft.com/v1.0/servicePrincipals/${spObjId}/owners/\$ref" --body "{\"@odata.id\": \"https://graph.microsoft.com/v1.0/users/${myObjId}\"}"

    ```

    Note that the documentation page doesn't add the API permissions via manifest or add an identifier url. Not sure if these are required.

1. Update Microsoft Fabric Admin Portal's Tenant settings

    <https://app.powerbi.com/admin-portal/tenantSettings?experience=fabric-developer> (or my [Contoso tenant](https://app.powerbi.com/admin-portal/tenantSettings?ctid=ac40fc60-2717-4051-a567-c0cd948f0ac9&experience=fabric-developer)).

    Scroll down to Developer settings.

    Enable _Allow service principals to create and use profiles_ for _The entire organization_.

1. Create required RBAC role assignments for the service principal

    This script is specific to my environment.

    - _Storage Blob Data Contributor_ role so that Terraform ca write state to the remote backend storage account
    - _Contributor_ on a specific subscription so that it can create Fabric capacity and add itself an admin.

    ```shell
    fabricSubscriptionId=$(az account show --name "Richard Cheney - Application - Internal" --query id -otsv)
    stateSubscriptionId=$(az account show --name "Richard Cheney - Platform - Management" --query id -otsv)
    storageAccountId=$(az storage account list --subscription $stateSubscriptionId --resource-group terraform --query "[?starts_with(name, 'terraformfabric')]|[0].id" -otsv)
    spObjId=$(az ad sp list --filter "displayname eq 'terraform_fabric_administrator'" --query "[0].id" -otsv)

    az role assignment create --assignee $spObjId --scope "/subscriptions/$fabricSubscriptionId" --role "Contributor"
    az role assignment create --assignee $spObjId --scope "$storageAccountId" --role "Storage Blob Data Contributor"
    ```

1. Display the GUIDs

    ```shell
    cat - <<EOF
    Tenant ID:                   $(az account show --query tenantId -otsv)
    App ID:                      $(az ad app show --id api://terraform_fabric_administrator --query appId -otsv)
    App Object ID:               $(az ad app show --id api://terraform_fabric_administrator --query id -otsv)
    Service Principal Object ID: $(az ad sp list --filter "displayname eq 'terraform_fabric_administrator'" --query "[0].id" -otsv)
    EOF
    ```
