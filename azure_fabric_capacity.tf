data "azurerm_client_config" "current" {}

data "azuread_group" "fabric_workload_identities" {
  display_name = var.fabric_workload_identities
}

data "azuread_group" "fabric_administrators" {
  display_name = var.fabric_administrators
}

data "azuread_users" "fabric_administrators" {
  object_ids = data.azuread_group.fabric_administrators.members
}

## locals {
##   capacity = [
##     {
##       ident    = "prod"
##       sku      = "F2"
##       location = "UK South"
##       admins   = data.azuread_group.fabric_administrators.object_id
##     }
##   ]
##
##   # Generate a unique identifier based on a hash of the resource group ID
##   uniq = substr(sha1(azurerm_resource_group.fabric.id), 0, 8)
## }

resource "azurerm_resource_group" "fabric" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_fabric_capacity" "fabric" {
  name                = var.fabric_capacity_name
  resource_group_name = azurerm_resource_group.fabric.name
  location            = azurerm_resource_group.fabric.location

  # Users must be user principal names and service principals must be object IDs
  # Avoids "BadRequest: All provided principals must be existing, user or service principals"
  # Ensure that the users or service principals are members of the groups
  administration_members = distinct(concat(
    data.azuread_users.fabric_administrators.user_principal_names,
    data.azuread_group.fabric_workload_identities.members
  ))

  sku {
    name = var.sku
    tier = "Fabric"
  }
}
