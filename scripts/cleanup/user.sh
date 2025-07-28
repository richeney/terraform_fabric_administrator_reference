#!/usr/bin/env bash

az ad app delete --id api://$(az account show --query tenantId -otsv)/fabric_terraform_provider
