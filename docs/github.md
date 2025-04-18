# Adding federated workload credentials for GitHub

You will need the gh CLI and be authenticated with `gh auth login`.

1. Set the default repo

    ```shell
    gh repo set-default richeney/terraform_fabric
    ```

1. Create the GitHub Actions variables

    ```shell
    fabric_subscription_id=$(az account show --name "Richard Cheney - Application - Internal" --query id -otsv)
    backend_subscription_id=$(az account show --name "Richard Cheney - Platform - Management" --query id -otsv)
    client_id=$(az ad app show --id api://terraform_fabric_administrator --query appId -otsv)
    tenant_id=$(az account show --name $fabric_subscription_id --query tenantId -otsv)
    storage_account_name=$(az storage account list --subscription $backend_subscription_id --resource-group "terraform" --query "[?starts_with(name,'terraformfabric')]|[0].name" -otsv)

    gh variable set ARM_TENANT_ID --body "$tenant_id"
    gh variable set ARM_SUBSCRIPTION_ID --body "$fabric_subscription_id"
    gh variable set ARM_CLIENT_ID --body "$client_id"
    gh variable set BACKEND_AZURE_SUBSCRIPTION_ID --body "$backend_subscription_id"
    gh variable set BACKEND_AZURE_RESOURCE_GROUP_NAME --body "terraform"
    gh variable set BACKEND_AZURE_STORAGE_ACCOUNT_NAME --body "$storage_account_name"
    gh variable set BACKEND_AZURE_STORAGE_ACCOUNT_CONTAINER_NAME --body "tfstate"
    gh repo view --json nameWithOwner --template '{{printf "https://github.com/%s/settings/variables/actions\n" .nameWithOwner}}'
    ```

1. Create the OpenID Connect configuration

    ```shell
    cat > oidc.credential.json <<CRED
    {
        "name": "terraform_fabric_administrator",
        "issuer": "https://token.actions.githubusercontent.com",
        "subject": "$(gh repo view --json nameWithOwner --template '{{printf "repo:%s:ref:refs/heads/main" .nameWithOwner}}')",
        "description": "Terraform Fabric Administrator service principal via OpenID Connect",
        "audiences": [
            "api://AzureADTokenExchange"
        ]
    }
    CRED

    az ad app federated-credential create --id api://terraform_fabric_administrator --parameters oidc.credential.json
    ```
