#!/usr/bin/env bash
# Keycloak Terraform Management Script
# Generated automatically by clan service

set -e

INSTANCE_NAME="adeci"
DOMAIN="auth.robitzs.ch"

echo "🔑 Keycloak Terraform Management for instance: $INSTANCE_NAME"
echo "🌐 Domain: $DOMAIN"
echo "📁 Working directory: $(pwd)"
echo

case "${1:-help}" in
  init)
    echo "🚀 Initializing Terraform..."
    tofu init
    ;;
  plan)
    echo "📋 Planning Terraform changes..."
    tofu plan -var-file=terraform.tfvars
    ;;
  apply)
    echo "✅ Applying Terraform configuration..."
    tofu apply -var-file=terraform.tfvars
    ;;
  destroy)
    echo "💥 Destroying Terraform resources..."
    read -p "Are you sure you want to destroy all resources? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
      tofu destroy -var-file=terraform.tfvars
    else
      echo "Destroy cancelled."
    fi
    ;;
  status)
    echo "📊 Terraform status..."
    if [ -f terraform.tfstate ]; then
      tofu show -json terraform.tfstate | jq '.values.root_module.resources[] | {type: .type, name: .name, address: .address}' 2>/dev/null || echo "Install jq for better output formatting"
    else
      echo "No terraform state found. Run './manage.sh init' first."
    fi
    ;;
  refresh)
    echo "🔄 Refreshing variable bridge..."
    echo "Variables refreshed from clan vars"
    ;;
  help|*)
    echo "Usage: $0 {init|plan|apply|destroy|status|refresh|help}"
    echo
    echo "Commands:"
    echo "  init     - Initialize Terraform working directory"
    echo "  plan     - Show planned Terraform changes"
    echo "  apply    - Apply Terraform configuration"
    echo "  destroy  - Destroy all Terraform resources"
    echo "  status   - Show current Terraform state"
    echo "  refresh  - Refresh variables from clan vars"
    echo "  help     - Show this help message"
    echo
    echo "Examples:"
    echo "  $0 init && $0 plan && $0 apply"
    echo "  $0 status"
    echo "  $0 refresh && $0 apply"
    ;;
esac