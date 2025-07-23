subscription_id      = "73568139-5c52-4066-a406-3e8533bb0f15"
resource_group_name  = "fabric-test"
fabric_capacity_name = "fabric-test-capacity"
sku                  = "F2"

workspaces = [
  {
    name        = "TestFinance",
    description = "Finance data.",
    group       = "Finance"
  },
  {
    name        = "TestEPOS"
    description = "Sales team's EPOS data.",
    group       = "Sales"
  },
  {
    name        = "TestOnline"
    description = "Sales team's online sales data.",
    group       = "Sales"
  }
]
