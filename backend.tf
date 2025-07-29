terraform {
  backend "azurerm" {
    subscription_id      = "73568139-5c52-4066-a406-3e8533bb0f15"
    resource_group_name  = "rg-terraform"
    storage_account_name = "terraformfabric6e44b6e4"
    container_name       = "dev"
    key                  = "terraform.tfstate"
    use_azuread_auth     = true
  }
}
