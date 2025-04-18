terraform {
  required_version = ">= 1.8, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.25"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.40"
    }
    fabric = {
      source  = "microsoft/fabric"
      version = "~> 1.0"
    }
  }
}

provider "azurerm" {
  features {}

  tenant_id       = "ac40fc60-2717-4051-a567-c0cd948f0ac9"
  subscription_id = var.subscription_id

  # GitHub Actions
  # use_oidc         = true   # Via ARM_USE_OIDC
  # use_azuread_auth = true   # Via ARM_USE_AZUREAD
  # client_id        = <guid> # Via ARM_CLIENT_ID

  storage_use_azuread = true

  resource_provider_registrations = "core"
  resource_providers_to_register = [
    "Microsoft.Fabric"
  ]
}

provider "fabric" {
  tenant_id = "ac40fc60-2717-4051-a567-c0cd948f0ac9"

  use_cli = true
  # GitHub Actions
  # use_oidc         = true   # Via ARM_USE_OIDC
  # use_azuread_auth = true   # Via ARM_USE_AZUREAD
  # client_id        = <guid> # Via ARM_CLIENT_ID
}

provider "azuread" {
  tenant_id = "ac40fc60-2717-4051-a567-c0cd948f0ac9"

  use_cli = true
  # GitHub Actions
  # use_oidc         = true   # Via ARM_USE_OIDC
  # use_azuread_auth = true   # Via ARM_USE_AZUREAD
  # client_id        = <guid> # Via ARM_CLIENT_ID
}
