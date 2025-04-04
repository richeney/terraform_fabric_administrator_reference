data "fabric_capacity" "fabric" {
  display_name = "fabric85085c7c"
}

resource "fabric_workspace" "example2" {
  display_name = "My Terraform Workspace"
  description  = "This is a test of the Terraform provider."
  capacity_id  = data.fabric_capacity.fabric.id

  identity = {
    type = "SystemAssigned"
  }
}