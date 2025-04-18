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