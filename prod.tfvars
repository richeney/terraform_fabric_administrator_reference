subscription_id      = "73568139-5c52-4066-a406-3e8533bb0f15"
fabric_capacity_name = "fabric-prod-capacity"
sku                  = "F2"

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
