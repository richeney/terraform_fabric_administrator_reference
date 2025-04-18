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


// Azure Variables

variable "subscription_id" {
  description = "The Azure subscription ID to use."
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group to create."
  type        = string
  default     = "fabric"
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

variable "ident" {
  description = "The identifier to use for the workspace."
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
