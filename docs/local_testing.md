# Local testing guide

Use workspaces and tfvars file for local testing using the same backend. There is a default workspace.

Based on <https://developer.hashicorp.com/terraform/cli/workspaces>.

This allows quick iterative development and testing prior to pushing to the origin and testing the pipeline.

Note that us

1. Create a workspace called test

    ```shell
    terraform workspace new test
    ```

1. Create a variable files for testing and production

    Example test.tfvars with names that will not clash with the production version.

    ```ruby
    subscription_id     = "73568139-5c52-4066-a406-3e8533bb0f15"
    resource_group_name = "fabric-test"
    ident               = "test"

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
    ```

1. Example plan command

    ```shell
    terraform plan -var-file=test.tfvars
    ```

    Command line -var and -var-file switches can be used to override other methods to set variables e.g. env vars, *.auto.tfvars, terraform.tfvars.

    Note that latter switches take precedence, so `terraform plan -var-file=test.tfvars -var "ident=demo"` would override the ident=test in the variable file.

## Other useful workspace commands

- List all workspaces

    ```shell
    terraform workspace list
    ```

- Show current workspace

    ```shell
    terraform workspace show
    ```

- Switch to a workspace

    ```shell
    terraform workspace select test
    ```
