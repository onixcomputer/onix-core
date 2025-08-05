#!/usr/bin/env bash
# Script to retrieve Vault keys from britton-fw after initialization

set -euo pipefail

echo "Retrieving Vault keys from britton-fw..."

# Get the root token from journalctl
ROOT_TOKEN=$(ssh root@britton-fw 'journalctl -u vault-auto-init | grep -o "hvs\.[a-zA-Z0-9]*" | head -1')

# Get the unseal keys from journalctl
UNSEAL_KEYS=$(ssh root@britton-fw 'journalctl -u vault-auto-init | grep -A20 "VAULT INITIALIZED SUCCESSFULLY" | grep -E "^Aug.*vault-auto-init-start\[[0-9]+\]:" | grep -o "\"[a-zA-Z0-9+/]*\"" | tr -d "\"" | grep -v "^{" | grep -v "^}" | head -5' | jq -Rs 'split("\n") | map(select(. != ""))')

if [ -z "$ROOT_TOKEN" ]; then
    echo "Failed to retrieve root token"
    exit 1
fi

if [ "$UNSEAL_KEYS" = "[]" ] || [ -z "$UNSEAL_KEYS" ]; then
    echo "Failed to retrieve unseal keys"
    exit 1
fi

echo "Root Token: $ROOT_TOKEN"
echo "Unseal Keys: $UNSEAL_KEYS"

# Save to temporary files
echo "$ROOT_TOKEN" > /tmp/vault-root-token
echo "$UNSEAL_KEYS" > /tmp/vault-unseal-keys

echo ""
echo "Keys saved to:"
echo "  - /tmp/vault-root-token"
echo "  - /tmp/vault-unseal-keys"
echo ""
echo "To update clan vars with these keys:"
echo "  1. clan vars set britton-fw vault-init/root_token < /tmp/vault-root-token"
echo "  2. clan vars set britton-fw vault-init/unseal_keys < /tmp/vault-unseal-keys"