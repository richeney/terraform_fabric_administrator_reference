# Variants of backend blocks

<https://developer.hashicorp.com/terraform/language/backend/azurerm#azure-active-directory-with-openid-connect-workload-identity-federation>

## Full

Full backend block. Fully declarative.

```ruby
terraform {
  backend "azurerm" {
    subscription_id      = "a7484f13-d60f-4e5a-a530-fdaade38716a"
    resource_group_name  = "terraform"
    storage_account_name = "terraformfabric562b54eb"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
    use_azuread_auth     = true
  }
}
```

Command to show an example backend.tf

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

Example GitHub Actions step.

```yaml
  - name: Terraform Init
    run: |
      terraform init
```

## Split

Split backend block. This forces the use of Azure Storage remote backend, but allows some to be specified via pipeline variables or secrets.

```ruby
terraform {
  backend "azurerm" {
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
    use_azuread_auth     = true
  }
}
```

Example GitHub Actions step.

```yaml
  - name: Terraform Init
    run: |
      terraform init \
      -backend-config="subscription_id=${{ vars.BACKEND_AZURE_SUBSCRIPTION_ID }}" \
      -backend-config="resource_group_name=${{vars.BACKEND_AZURE_RESOURCE_GROUP_NAME}}" \
      -backend-config="storage_account_name=${{vars.BACKEND_AZURE_STORAGE_ACCOUNT_NAME}}"
```

## Near empty

Empty backend block. Will write to local terraform.tfstate without the -backend-config switches.

```ruby
terraform {
  backend "azurerm" {
    use_azuread_auth     = true
  }
}
```

The use_azuread_auth boolean only comes into effect when authenticating to an Azure Storage Account. It cannot be set via the -backend-config switches.

Example GitHub Actions step.

```yaml
  - name: Terraform Init
    run: |
      terraform init \
      -backend-config="subscription_id=${{ vars.BACKEND_AZURE_SUBSCRIPTION_ID }}" \
      -backend-config="resource_group_name=${{vars.BACKEND_AZURE_RESOURCE_GROUP_NAME}}" \
      -backend-config="storage_account_name=${{vars.BACKEND_AZURE_STORAGE_ACCOUNT_NAME}}" \
      -backend-config="container_name=${{vars.BACKEND_AZURE_STORAGE_ACCOUNT_CONTAINER_NAME}}" \
      -backend-config="key=terraform.tfstate"
```

## For later - private runners

```shell
az storage account network-rule add --account-name $storage_account_name --ip-address $(curl -s api.ipify.org) --action Allow
```
