# Common Library for Fabric Admin Scripts

This directory contains shared functions and utilities used across multiple scripts in the Fabric Admin environment.

## Files

### `common.sh`
Common functions for option parsing, error handling, and prerequisites checking.

#### Functions

- **`error(message)`**: Displays an error message and exits with code 1
- **`usage_bootstrap()`**: Shows help text for bootstrap.sh script
- **`usage_github()`**: Shows help text for github.sh script
- **`parse_options(script_type, arguments...)`**: Parses command line options
- **`set_defaults(script_type)`**: Sets default values for variables
- **`check_prerequisites(script_type)`**: Validates required tools and authentication
- **`get_subscription_info()`**: Retrieves and validates Azure subscription information

#### Usage in Scripts

To use the common library in a script:

```bash
#!/usr/bin/env bash

# Load common functions
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib/common.sh"

# Check prerequisites
check_prerequisites "bootstrap"  # or "github"

# Get subscription information
get_subscription_info

# Parse options
parse_options "bootstrap" "$@"  # or "github"

# Set default values
set_defaults "bootstrap"  # or "github"
```

#### Supported Options

| Short | Long | Description | Bootstrap | GitHub |
|-------|------|-------------|-----------|--------|
| `-g` | `--resource-group` | Resource group name | ✓ | ✓ |
| `-i` | `--identity` | Managed identity name | ✓ | ✓ |
| `-l` | `--location` | Azure region | ✓ | ✗ |
| `-s` | `--management-subscription-id` | Management subscription ID | ✓ | ✗ |
| `-m` | `--management-subscription-id` | Management subscription ID | ✓ | ✓ |
| `-r` | `--role` | RBAC role name | ✓ | ✗ |
| `-w` | `--workload-subscription-id` | Workload subscription ID | ✓ | ✓ |
| `-h` | `--help` | Show help message | ✓ | ✓ |

#### Script Types

- **`bootstrap`**: For bootstrap.sh script that creates Azure resources
- **`github`**: For github.sh script that configures GitHub Actions

## Adding New Scripts

To create a new script that uses the common library:

1. Source the `common.sh` file
2. Call `check_prerequisites()` with your script type
3. Call `get_subscription_info()` to get Azure context
4. Call `parse_options()` with your script type and arguments
5. Call `set_defaults()` with your script type
6. Add your script-specific logic

If you need a new script type, update the common.sh file with:
- New usage function
- Support in `parse_options()`, `set_defaults()`, and `check_prerequisites()`
