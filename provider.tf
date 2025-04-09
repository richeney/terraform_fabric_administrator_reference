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
  subscription_id = "73568139-5c52-4066-a406-3e8533bb0f15"

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

  # GitHub Actions
  # use_oidc         = true   # Via ARM_USE_OIDC
  # use_azuread_auth = true   # Via ARM_USE_AZUREAD
  # client_id        = <guid> # Via ARM_CLIENT_ID
}

provider "azuread" {
  tenant_id = "ac40fc60-2717-4051-a567-c0cd948f0ac9"

  # GitHub Actions
  # use_oidc         = true   # Via ARM_USE_OIDC
  # use_azuread_auth = true   # Via ARM_USE_AZUREAD
  # client_id        = <guid> # Via ARM_CLIENT_ID
}