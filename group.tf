data "azuread_group" "fabric_administrators" {
    display_name = "Fabric Administrators"
}

output "fabric_administrators_object_id" {
    value = data.azuread_group.fabric_administrators.object_id
}