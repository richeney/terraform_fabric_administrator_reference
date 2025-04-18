# Service Principal with OpenID Connect

Based on <https://registry.terraform.io/providers/microsoft/fabric/latest/docs/guides/auth_app_reg_spn>.

1. Core app reg and service principal

    This script

    - Creates the app reg
        - uses a manifest.json file, which has the following application API permissions for Microsoft Graph
        - Group.Read.All
        - User.ReadBasic.All
    - Creates a service principal
    - Adds you as owner to both, which is optional but recommended
    - Grants admin consent

    ```shell
    appObjId=$(az ad app create --display-name terraform_fabric_administrator --required-resource-accesses @manifest.role.json --identifier-uris api://terraform_fabric_administrator --query id -otsv)
    appId=$(az ad app show --id $appObjId --query appId -otsv)
    spObjId=$(az ad sp create --id $appObjId --query id -otsv)
    myObjId=$(az ad signed-in-user show --query id -otsv)
    az ad app owner add --id $appObjId --owner-object-id $myObjId
    az rest --method POST --url "https://graph.microsoft.com/v1.0/servicePrincipals/${spObjId}/owners/\$ref" --body "{\"@odata.id\": \"https://graph.microsoft.com/v1.0/users/${myObjId}\"}"
    az ad app permission admin-consent --id $appId
    ```

    Note that the documentation page doesn't add an identifier url, and it serves no real puepose here except to make it possible to show the app reg via that identifier.

1. Update Microsoft Fabric Admin Portal's Tenant settings

    <https://app.powerbi.com/admin-portal/tenantSettings?experience=fabric-developer> (or my [Contoso tenant](https://app.powerbi.com/admin-portal/tenantSettings?ctid=ac40fc60-2717-4051-a567-c0cd948f0ac9&experience=fabric-developer)).

    Scroll down to Developer settings.

    Enable _Allow service principals to create and use profiles_ for _The entire organization_.

    There is no need to add in API permissions for Fabric for service principals. (There are only two there.) It is a rather blunt permissions model right now.

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

1. Add the fabric administrator to the Fabric Administrators security group

    ```shell
    az ad group member add --group "Fabric Administrators" --member-id $(az ad sp list --filter "displayname eq 'terraform_fabric_administrator'" --query "[0].id" -otsv)
    ```

    This is useful if aiming to ensure only selected service principals can be used.

    - Service Principal objectId needs to be in the Fabric Administrators group to use the Fabric APIs
        - <https://app.powerbi.com/admin-portal/tenantSettings?experience=fabric-developer> ([my Contoso tenant](https://app.powerbi.com/admin-portal/tenantSettings?ctid=ac40fc60-2717-4051-a567-c0cd948f0ac9&experience=fabric-developer))
    - Additionally user SPNs and workload identity appIds should be in the Fabric capacity's list of Capacity Administrators for any resources or data sources related to the Azure Fabric Capacity resource

1. Commands to display the GUIDs

    ```shell
    cat - <<EOF
    Tenant ID:                   $(az account show --query tenantId -otsv)
    App ID:                      $(az ad app show --id api://terraform_fabric_administrator --query appId -otsv)
    App Object ID:               $(az ad app show --id api://terraform_fabric_administrator --query id -otsv)
    Service Principal Object ID: $(az ad sp list --filter "displayname eq 'terraform_fabric_administrator'" --query "[0].id" -otsv)
    EOF
    ```
