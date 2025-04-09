data "azurerm_client_config" "current" {}


locals {
  uniq = substr(sha1(azurerm_resource_group.fabric.id), 0, 8)
}

resource "azurerm_resource_group" "fabric" {
  name     = "fabric"
  location = "UK South"
}

resource "azurerm_fabric_capacity" "fabric" {
  name                = "fabric${local.uniq}"
  resource_group_name = azurerm_resource_group.fabric.name
  location            = azurerm_resource_group.fabric.location

  # Users as UPN, service principals as object ID
  # Avoids "BadRequest: All provided principals must be existing, user or service principals"
  administration_members = join([
    "admin@MngEnvMCAP520989.onmicrosoft.com",
    data.azurerm_client_config.current.object_id
  ])

  sku {
    name = "F2"
    tier = "Fabric"
  }
}
