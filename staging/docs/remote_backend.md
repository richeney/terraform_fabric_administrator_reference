# Create the remote backend

1. Select the context

    Using the management subscription in the platform

    ```shell
    az account set --subscription "Richard Cheney - Platform - Management"
    ```

1. Create the storage account

    ```shell
    az group create --name terraform
    storage_account_name="terraformfabric$(az group show --name terraform --query id -otsv | sha1sum | cut -c1-8)"
    storage_account_id=$(az storage account create --name $storage_account_name --min-tls-version TLS1_2 --sku Standard_LRS --https-only true --default-action "Allow" --public-network-access "Enabled"  --allow-shared-key-access false --allow-blob-public-access false --query id -otsv)
    az storage account blob-service-properties update --account-name $storage_account_name --enable-versioning --enable-delete-retention --delete-retention-days 7
    az storage container create --name tfstate --account-name $storage_account_name --auth-mode login
    ```

1. Show an example backend.tf

    ```shell
    subscription_id=$(az account show --name "Richard Cheney - Platform - Management" --query id -otsv)
    storage_account_name=$(az storage account list --subscription $subscription_id --resource-group "terraform" --query "[?starts_with(name,'terraformfabric')]|[0].name" -otsv)

    cat - <<BACKEND
    terraform {
      backend "azurerm" {
        subscription_id      = "$subscription_id"
        resource_group_name  = "terraform"
        storage_account_name = "$storage_account_name"
        container_name       = "tfstate"
        key                  = "terraform.tfstate"
        use_azuread_auth     = true
      }
    }
    BACKEND
    ```

1. Replace the contents of backend.tf with the displayed terraform block

## For later - private runners

```shell
az storage account network-rule add --account-name $storage_account_name --ip-address $(curl -s api.ipify.org) --action Allow
```
