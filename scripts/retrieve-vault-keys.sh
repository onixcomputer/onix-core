#!/usr/bin/env bash
# Script to retrieve Vault keys from a machine and display them

set -euo pipefail

MACHINE="${1:-britton-fw}"

echo "Retrieving Vault keys from machine: $MACHINE"
echo ""

# Retrieve and display root token
echo "Root Token:"
ssh "root@$MACHINE" "cat /var/lib/vault/init-keys/root_token 2>/dev/null" || {
    echo "Failed to retrieve root token - is Vault initialized?"
    exit 1
}
echo ""

# Retrieve and display unseal keys
echo "Unseal Keys:"
ssh "root@$MACHINE" "cat /var/lib/vault/init-keys/unseal_keys 2>/dev/null | jq -r '.[]' 2>/dev/null || cat /var/lib/vault/init-keys/unseal_keys" || {
    echo "Failed to retrieve unseal keys"
    exit 1
}

echo ""
echo "To save these keys to clan vars, SSH to the machine and run:"
echo "  ssh root@$MACHINE"
echo "  cd /path/to/clan/repo"
echo "  clan vars generate $MACHINE --generator vault-keys --regenerate"