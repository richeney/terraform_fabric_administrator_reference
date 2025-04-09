terraform {
  required_version = ">= 1.8, < 2.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.25"
    }
    fabric = {
      source  = "microsoft/fabric"
      version = "1.0.0"
    }
  }
}

provider "azurerm" {
  features {}

  tenant_id       = "ac40fc60-2717-4051-a567-c0cd948f0ac9"
  subscription_id = "73568139-5c52-4066-a406-3e8533bb0f15"

  storage_use_azuread = true

  resource_provider_registrations = "core"
  resource_providers_to_register = [
    "Microsoft.Fabric"
  ]
}

provider "fabric" {
  # The Fabric provider requires the Azure AD tenant ID and subscription ID
  # to be set in the provider block.
  tenant_id = "ac40fc60-2717-4051-a567-c0cd948f0ac9"

  # use_cli = true
  # use_msi  = false
  # use_oidc = false
}
