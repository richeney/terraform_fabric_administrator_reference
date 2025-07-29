#!/usr/bin/env bash

# Common functions and option parsing for Fabric Admin scripts

error() {
    echo "Error: $1" >&2
    exit 1
}

usage_bootstrap() {
    cat << EOF
Usage: $0 [OPTIONS]

Bootstraps the resources required for a Fabric Admin environment deployed via Terraform.
Creates an App Registration, Entra security group, Storage Account, and Managed Identity.

OPTIONS:
    -g, --resource-group <name>       Resource group name (required)
    -i, --identity <name>             Managed identity name (default: mi-terraform)
    -l, --location <region>           Azure region (default: $AZURE_DEFAULTS_LOCATION or uksouth)
    -s, --management-subscription-id <id>  Management subscription ID (default: current subscription)
    -r, --role <role_name>            RBAC role to assign to managed identity on workload subscription (default: Reader)
    -w, --workload-subscription-id <id>    Workload subscription ID (default: current subscription)
    -h, --help, -?                   Show this help message and exit

EXAMPLES:
    $0 -g my-rg                                                                               # Minimal required argument
    $0 -g my-rg -l eastus                                                                     # Custom resource group and location
    $0 --resource-group my-rg --location eastus                                               # Using long options
    $0 -g my-rg --role "Contributor" --workload-subscription-id "12345678-..."                # Assign Contributor role to specific subscription
    $0 -g my-rg --identity my-terraform-identity --management-subscription-id "87654321-..."  # Custom identity and management subscription

PREREQUISITES:
    - Azure CLI installed and logged in (az login)
    - Microsoft Fabric CLI installed and logged in (fab auth login)
    - jq installed (recommended)
    - Fabric Administrator role in your tenant

The script will create:
    1. App Registration for Fabric Terraform Provider
    2. Storage Account for Terraform state backend
    3. Entra security group for Fabric workload identities
    4. Managed Identity for Terraform automation
    5. Configure Fabric tenant settings for service principal access

EOF
    exit 0
}

usage_github() {
    cat << EOF
Usage: $0 [OPTIONS]

Configures GitHub Actions for a Fabric Admin environment with OpenID Connect authentication.
Sets up GitHub variables and federated credentials for the managed identity.

OPTIONS:
    -g, --resource-group <name>    Resource group name (default: rg-terraform)
    -i, --identity <name>          Managed identity name (default: mi-terraform)
    -m, --management-subscription-id <id>  Management subscription ID (default: current subscription)
    -w, --workload-subscription-id <id>    Workload subscription ID (default: current subscription)
    -h, --help, -?                 Show this help message and exit

EXAMPLES:
    $0                                                             # Use all defaults
    $0 -g my-rg -i my-identity                                     # Custom resource group and identity
    $0 --resource-group my-rg --identity my-terraform-identity     # Using long options
    $0 -g my-rg --management-subscription-id "12345678-..."        # Custom subscription

PREREQUISITES:
    - Azure CLI installed and logged in (az login)
    - GitHub CLI installed and logged in (gh auth login)
    - Current directory must be a git repository with GitHub remote
    - Managed identity must already exist (run bootstrap.sh first)
    - jq installed (recommended)

The script will configure:
    1. GitHub Actions repository variables for Azure authentication
    2. Federated credential on the managed identity for GitHub Actions
    3. Backend configuration variables for Terraform state

EOF
    exit 0
}

usage_backend() {
    cat << EOF
Usage: $0 [OPTIONS]

Generates a Terraform backend configuration file for Azure Remote State.
Creates a backend.tf file with the Azure storage backend configuration.

OPTIONS:
    -g, --resource-group <name>    Resource group name (default: rg-terraform)
    -c, --container <name>         Storage container name (default: dev)
    -k, --key <path>               Terraform state file key/path (default: terraform.tfstate)
    -m, --management-subscription-id <id>  Management subscription ID (default: current subscription)
    -h, --help, -?                 Show this help message and exit

EXAMPLES:
    $0                                                                 # Use all defaults (dev container)
    $0 -g my-rg -c prod                                                # Custom resource group and container
    $0 --resource-group my-rg --container prod --key prod.tfstate      # Using long options for production
    $0 -g my-rg --management-subscription-id "12345678-..."            # Custom management subscription

PREREQUISITES:
    - Azure CLI installed and logged in (az login)
    - Must be run from within a git repository
    - Storage account must already exist (run bootstrap.sh first)

The script will generate:
    1. backend.tf file with Azure storage backend configuration
    2. Configured for Azure AD authentication (use_azuread_auth = true)

EOF
    exit 0
}

# Parse common options for both scripts
# Usage: parse_options "$@"
# Sets global variables: rg, managed_identity_name, location, management_subscription_id, workload_subscription_id, workload_subscription_rbac_role
parse_options() {
    local script_type="$1"
    shift

    while getopts ":g:i:l:m:r:s:w:c:k:h?-:" opt; do
        case $opt in
            g) rg="$OPTARG"
            ;;
            i) managed_identity_name="$OPTARG"
            ;;
            l) location="$OPTARG"
            ;;
            m) management_subscription_id="$OPTARG"
            ;;
            r) workload_subscription_rbac_role="$OPTARG"
            ;;
            s) management_subscription_id="$OPTARG"  # For bootstrap script compatibility
            ;;
            w) workload_subscription_id="$OPTARG"  # For github script
            ;;
            c) container_name="$OPTARG"  # For backend script
            ;;
            k) state_key="$OPTARG"  # For backend script
            ;;
            h|?)
                case "$script_type" in
                    "bootstrap") usage_bootstrap ;;
                    "github") usage_github ;;
                    "backend") usage_backend ;;
                    *) error "Unknown script type: $script_type" ;;
                esac
            ;;
            -) case "${OPTARG}" in
                help)
                    case "$script_type" in
                        "bootstrap") usage_bootstrap ;;
                        "github") usage_github ;;
                        "backend") usage_backend ;;
                        *) error "Unknown script type: $script_type" ;;
                    esac
                ;;
                resource-group) rg="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                ;;
                resource-group=*) rg="${OPTARG#*=}"
                ;;
                identity) managed_identity_name="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                ;;
                identity=*) managed_identity_name="${OPTARG#*=}"
                ;;
                location) location="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                ;;
                location=*) location="${OPTARG#*=}"
                ;;
                management-subscription-id) management_subscription_id="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                ;;
                management-subscription-id=*) management_subscription_id="${OPTARG#*=}"
                ;;
                role) workload_subscription_rbac_role="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                ;;
                role=*) workload_subscription_rbac_role="${OPTARG#*=}"
                ;;
                subscription-id) management_subscription_id="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                ;;
                subscription-id=*) management_subscription_id="${OPTARG#*=}"
                ;;
                workload-subscription-id) workload_subscription_id="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                ;;
                workload-subscription-id=*) workload_subscription_id="${OPTARG#*=}"
                ;;
                container) container_name="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                ;;
                container=*) container_name="${OPTARG#*=}"
                ;;
                key) state_key="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                ;;
                key=*) state_key="${OPTARG#*=}"
                ;;
                *) echo "Error: Invalid option --$OPTARG" >&2; exit 1
                ;;
               esac
            ;;
            \?) echo "Error: Invalid option -$OPTARG" >&2; exit 1
            ;;
        esac
    done
}

# Set default values based on script type
# Usage: set_defaults "bootstrap" or set_defaults "github"
set_defaults() {
    local script_type="$1"

    case "$script_type" in
        "bootstrap")
            # Resource group is required for bootstrap
            [[ -z "$rg" ]] && error "Resource group is required. Use -g or --resource-group to specify."
            managed_identity_name="${managed_identity_name:-mi-terraform}"
            location="${location:-${AZURE_DEFAULTS_LOCATION:-uksouth}}"
            management_subscription_id="${management_subscription_id:-$subscription_id}"
            workload_subscription_id="${workload_subscription_id:-$subscription_id}"
            workload_subscription_rbac_role="${workload_subscription_rbac_role:-Reader}"
            ;;
        "github")
            # GitHub script has defaults for all options
            rg="${rg:-rg-terraform}"
            managed_identity_name="${managed_identity_name:-mi-terraform}"
            management_subscription_id="${management_subscription_id:-$subscription_id}"
            workload_subscription_id="${workload_subscription_id:-$subscription_id}"
            ;;
        "backend")
            # Backend script has defaults for all options
            rg="${rg:-rg-terraform}"
            container_name="${container_name:-dev}"
            state_key="${state_key:-terraform.tfstate}"
            management_subscription_id="${management_subscription_id:-$subscription_id}"
            ;;
        *)
            error "Unknown script type: $script_type"
            ;;
    esac
}

# Common prerequisite checks
check_prerequisites() {
    local script_type="$1"

    # Common checks for all scripts
    command -v az >/dev/null 2>&1 || error "Azure CLI (az) is not installed."
    az account show >/dev/null 2>&1 || error "Not logged in to Azure CLI. Please run 'az login'."
    command -v jq >/dev/null 2>&1 || echo "Warning: jq not found. Some features may not work as expected."

    # Script-specific checks
    case "$script_type" in
        "bootstrap")
            command -v fab >/dev/null 2>&1 || error "Microsoft Fabric CLI (fab) is not installed. Install with: pip install ms-fabric-cli"
            fab api --method get admin/tenantsettings >/dev/null 2>&1 || error "Not logged in to Fabric CLI or insufficient permissions. Please run 'fab auth login' and ensure you have Fabric Administrator role."
            ;;
        "github")
            command -v gh >/dev/null 2>&1 || error "GitHub CLI (gh) is not installed."
            gh auth status >/dev/null 2>&1 || error "Not logged in to GitHub CLI. Please run 'gh auth login'."
            git rev-parse --is-inside-work-tree >/dev/null 2>&1 || error "Not a git repository."
            git remote | grep -q . || error "No git remote found."
            ;;
        "backend")
            git rev-parse --is-inside-work-tree >/dev/null 2>&1 || error "Not a git repository."
            ;;
    esac
}

# Get subscription ID and validate
get_subscription_info() {
    subscription_id=$(az account show --query id -otsv)

    # Validate subscription_id is a non-empty GUID
    if ! [[ "$subscription_id" =~ ^[0-9a-fA-F-]{36}$ ]]; then
        error "Not logged in to Azure CLI or invalid subscription ID."
    fi
}
