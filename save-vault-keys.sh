#!/usr/bin/env bash
# Script to save Vault keys for auto-unseal

set -euo pipefail

if [ $# -ne 2 ]; then
    echo "Usage: $0 <root-token> <unseal-keys-json>"
    echo ""
    echo "Example:"
    echo "  $0 'hvs.xxxxxxxxxx' '[\"key1\",\"key2\",\"key3\",\"key4\",\"key5\"]'"
    echo ""
    echo "The unseal keys should be provided as a JSON array."
    exit 1
fi

ROOT_TOKEN="$1"
UNSEAL_KEYS="$2"

# Validate JSON
if ! echo "$UNSEAL_KEYS" | jq . >/dev/null 2>&1; then
    echo "Error: Invalid JSON for unseal keys"
    exit 1
fi

# Save to remote machine
echo "Saving keys to britton-fw..."
ssh root@britton-fw "mkdir -p /var/lib/vault/init-keys && chmod 700 /var/lib/vault/init-keys"
echo "$ROOT_TOKEN" | ssh root@britton-fw "cat > /var/lib/vault/init-keys/root_token && chmod 600 /var/lib/vault/init-keys/root_token"
echo "$UNSEAL_KEYS" | ssh root@britton-fw "cat > /var/lib/vault/init-keys/unseal_keys && chmod 600 /var/lib/vault/init-keys/unseal_keys"

echo "Keys saved to britton-fw:/var/lib/vault/init-keys/"
echo ""
echo "Now run these commands to pull the keys into clan vars:"
echo "  clan vars generate britton-fw --generator vault-init --regenerate"
echo "  clan machines update britton-fw"