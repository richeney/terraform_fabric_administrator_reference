# Additional ADLS and shortcut for Online workspace's Silver tier

locals {
  # Generate a unique identifier based on a hash of the resource group ID
  uniq = substr(sha1(azurerm_resource_group.adls.id), 0, 8)

}

resource "azurerm_resource_group" "adls" {
  name     = var.adls_resource_group_name
  location = var.location
}

resource "azurerm_storage_account" "online" {
  name                     = "onlineadls${local.uniq}"
  resource_group_name      = var.adls_resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  is_hns_enabled           = true
  min_tls_version          = "TLS1_2"

  default_to_oauth_authentication = true
  shared_access_key_enabled       = false
  public_network_access_enabled   = true
  allow_nested_items_to_be_public = false

  network_rules {
    default_action = "Deny"
    ip_rules = [
      data.http.public_ip.response_body, # Public IP address from ipinfo.io
    ]
    virtual_network_subnet_ids = []

    bypass = [
      "AzureServices",
    ]

    private_link_access {
      endpoint_resource_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Fabric/workspaces/${fabric_workspace.fabric["Online"].id}"
    }

    # Needed for internal Microsoft subscriptions!
    private_link_access {
      endpoint_resource_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Security/datascanners/StorageDataScanner"
    }

  }
}

resource "azurerm_storage_container" "adls_container" {
  name                  = "silver"
  storage_account_id    = azurerm_storage_account.online.id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "online_sami_blob_reader" {
  for_each             = var.rbac ? toset(["online_sami_blob_reader"]) : []
  scope                = azurerm_storage_account.online.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = fabric_workspace.fabric["Online"].identity.service_principal_id
}

resource "fabric_shortcut" "online_silver" {
  for_each     = toset(var.connection_id != null ? ["silver"] : [])
  workspace_id = fabric_workspace.fabric["Online"].id
  item_id      = fabric_lakehouse.silver["Online"].id
  path         = "Files/My Subfolder"
  name         = "My Shortcut to Silver Lakehouse's ADLS Gen2"


  target = {
    adls_gen2 = {
      location      = azurerm_storage_account.online.primary_dfs_endpoint
      subpath       = azurerm_storage_container.adls_container.name
      connection_id = var.connection_id # Create manually then set variable and re-apply ☹️
    }
  }

}
