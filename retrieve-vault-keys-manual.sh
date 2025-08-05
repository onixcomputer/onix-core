#!/usr/bin/env bash
# Manual script to retrieve and save Vault keys

set -euo pipefail

echo "Manual Vault Key Retrieval"
echo "=========================="
echo ""
echo "Since the keys weren't saved during initialization, you'll need to:"
echo ""
echo "1. Get the keys from whoever initialized Vault, or"
echo "2. Re-initialize Vault (WARNING: This will DELETE all data!)"
echo ""
echo "To re-initialize Vault (DESTRUCTIVE):"
echo "  ssh root@britton-fw 'systemctl stop vault && rm -rf /var/lib/vault/* && systemctl start vault'"
echo "  clan machines update britton-fw"
echo ""
echo "To manually save existing keys to clan vars:"
echo "  # Save root token:"
echo "  echo 'YOUR_ROOT_TOKEN' | clan vars set britton-fw vault-init/root_token"
echo "  "
echo "  # Save unseal keys (as JSON array):"
echo "  echo '[\"key1\", \"key2\", \"key3\", \"key4\", \"key5\"]' | clan vars set britton-fw vault-init/unseal_keys"
echo ""
echo "After saving the keys, run:"
echo "  clan machines update britton-fw"
echo ""
echo "The auto-unseal service will then use these keys to automatically unseal Vault on restart."