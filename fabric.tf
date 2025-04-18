data "fabric_capacity" "fabric" {
  display_name = azurerm_fabric_capacity.fabric.name

  lifecycle {
    postcondition {
      condition     = self.state == "Active"
      error_message = "Fabric Capacity is not in Active state. Please check the Fabric Capacity status."
    }
  }
}

data "azuread_group" "group" {
  for_each     = toset([for workspace in var.workspaces : workspace.group])
  display_name = each.value
}

locals {
  workspaces = {
    for workspace in var.workspaces : workspace.name => {
      name         = workspace.name
      description  = workspace.description
      workspace_id = fabric_workspace.fabric[workspace.name].id
      group        = workspace.group
      object_id    = data.azuread_group.group[workspace.group].object_id
    }
  }
}

resource "fabric_workspace" "fabric" {
  for_each     = { for workspace in var.workspaces : workspace.name => workspace }
  display_name = each.value.name
  description  = each.value.description
  capacity_id  = data.fabric_capacity.fabric.id

  identity = {
    type = "SystemAssigned"
  }
}

resource "fabric_workspace_role_assignment" "fabric" {
  for_each     = local.workspaces
  workspace_id = each.value.workspace_id
  principal = {
    id   = each.value.object_id
    type = "Group"
  }
  role = "Member"
}

resource "fabric_lakehouse" "bronze" {
  for_each     = local.workspaces
  display_name = "${title(each.value.name)}Bronze"
  description  = "Bronze tier for the ${each.value.description}"
  workspace_id = each.value.workspace_id
}

resource "fabric_lakehouse" "silver" {
  for_each     = local.workspaces
  display_name = "${title(each.value.name)}Silver"
  description  = "Bronze tier for the ${each.value.description}"
  workspace_id = each.value.workspace_id

  configuration = {
    enable_schemas = true
  }
}

resource "fabric_lakehouse" "gold" {
  for_each     = local.workspaces
  display_name = "${title(each.value.name)}Gold"
  description  = "Gold tier for the ${each.value.description}"
  workspace_id = each.value.workspace_id

  configuration = {
    enable_schemas = true
  }
}
