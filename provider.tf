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

  subscription_id = var.subscription_id

  # tenant_id        = <guid> # ARM_TENANT_ID
  # use_oidc         = true   # ARM_USE_OIDC
  # use_azuread_auth = true   # ARM_USE_AZUREAD
  # client_id        = <guid> # ARM_CLIENT_ID

  storage_use_azuread = true

  resource_provider_registrations = "core"
  resource_providers_to_register = [
    "Microsoft.Fabric"
  ]
}

provider "fabric" {
  # tenant_id        = <guid> # ARM_TENANT_ID
  # use_oidc         = true   # ARM_USE_OIDC
  # use_azuread_auth = true   # ARM_USE_AZUREAD
  # client_id        = <guid> # ARM_CLIENT_ID
  preview = true
}

provider "azuread" {
  # tenant_id        = <guid> # ARM_TENANT_ID
  # use_oidc         = true   # ARM_USE_OIDC
  # use_azuread_auth = true   # ARM_USE_AZUREAD
  # client_id        = <guid> # ARM_CLIENT_ID
}

provider "http" {
  # Use the HTTP provider to fetch the public IP address for network rules
  # This is useful for allowing access from the current machine's public IP
}