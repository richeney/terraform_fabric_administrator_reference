data "fabric_capacity" "fabric" {
  display_name = "fabric85085c7c"
}

resource "fabric_workspace" "fabric" {
  for_each     = ["production", "development", "staging"]
  display_name = each.value
  description  = "This is a test of the Terraform provider."
  capacity_id  = data.fabric_capacity.fabric.id

  identity = {
    type = "SystemAssigned"
  }
}
