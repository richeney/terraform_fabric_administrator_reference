#!/usr/bin/env bash

# Bootstraps the resources etc for a Fabric Admin  environment deployed via Terraform
# App reg, Entra group, Storage Account, Managed Identity

error() {
    echo "Error: $1" >&2
    exit 1
}

# Check for Azure CLI
command -v az >/dev/null 2>&1 || error "Azure CLI (az) is not installed."

# Check for required Azure login
az account show >/dev/null 2>&1 || error "Not logged in to Azure CLI. Please run 'az login'."

# Check for jq (used for JSON parsing if needed)
command -v jq >/dev/null 2>&1 || echo "Warning: jq not found. Some features may not work as expected."

# Check for GitHub CLI
command -v gh >/dev/null 2>&1 || error "GitHub CLI (gh) is not installed."

subscription_id=$(az account show --query id -otsv)

# Validate subscription_id is a non-empty GUID
if ! [[ "$subscription_id" =~ ^[0-9a-fA-F-]{36}$ ]]; then
    error "Not logged in to Azure CLI or invalid subscription ID."
fi