# User setup

Follow <https://registry.terraform.io/providers/microsoft/fabric/latest/docs/guides/auth_app_reg_user> for manual steps.

Below is a script to accelerate.

```shell
az ad app create --display-name fabric_terraform_provider --identifier-uris api://fabric_terraform_provider --output none
az ad app update --id api://fabric_terraform_provider --required-resource-accesses @manifest.scope.json
az ad app update --id api://fabric_terraform_provider --set api=@api.oauth2PermissionScopes.json
az ad app update --id api://fabric_terraform_provider --set api=@api.preAuthorizedApplications.json
az ad app owner add --id api://fabric_terraform_provider --owner-object-id $(az ad signed-in-user show --query id -otsv)
az ad app show --id api://fabric_terraform_provider
echo "az login --scope api://fabric_terraform_provider/.default --tenant $(az account show --query tenantId -otsv)"
```

```shell
az login --scope api://fabric_terraform_provider/.default
```

You may also need to use --tenant in multi-tenant scenarios.
