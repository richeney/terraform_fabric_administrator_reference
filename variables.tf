// Fabric Variables

variable "workspaces" {
  description = "The list of workspaces to create. Group should match the displayName of the Azure AD group."
  type = list(object({
    name        = string
    description = string
    group       = string
  }))

  default  = []
  nullable = false

  /*  # Example:
  workspaces = [
    {
      name        = "Finance",
      description = "Finance data.",
      group       = "Finance"
    },
    {
      name        = "EPOS"
      description = "Sales team's EPOS data.",
      group       = "Sales"
    },
    {
      name        = "Online"
      description = "Sales team's online sales data.",
      group       = "Sales"
    }
  ]
  */
}

// Additional Fabric resources

variable "adls_resource_group_name" {
  description = "The name of the resource group for the ADLS Gen2 storage account."
  type        = string
  default     = "rg-fabric-data"
}

variable "connection_id" {
  # Currently manual ☹️
  # <https://github.com/microsoft/terraform-provider-fabric/issues/343
  description = "The connection ID for the ADLS Gen2 storage account."
  type        = string
  default     = null
}

// Azure Variables

variable "subscription_id" {
  description = "The Azure subscription ID to use."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group to create."
  type        = string
  default     = "rg-fabric-capacities"
}

variable "location" {
  description = "The location to create the resource group in."
  type        = string
  default     = "UK South"
}

variable "sku" {
  description = "The SKU to use for the workspace."
  type        = string
  default     = "F2"
}

variable "fabric_capacity_name" {
  description = "The name to use for the Azure fabric capacity."
  type        = string
  default     = "fabric"
}

variable "fabric_workload_identities" {
  description = "The Microsoft Fabric Workload Identities group. Must only contain service principals."
  type        = string
  default     = "Microsoft Fabric Workload Identities"
}

variable "fabric_administrators" {
  description = "The Microsoft Fabric Administrators group. Must only contain member users."
  type        = string
  default     = "Microsoft Fabric Administrators"
}
