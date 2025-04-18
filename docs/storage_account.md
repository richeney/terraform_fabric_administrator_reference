# Create the storage account remote backend

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
