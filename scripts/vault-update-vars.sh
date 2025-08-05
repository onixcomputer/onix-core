#!/usr/bin/env bash
# Script to update clan vars with Vault-generated keys

set -euo pipefail

MACHINE="${1:-britton-fw}"

echo "Updating Vault keys in clan vars for machine: $MACHINE"

# Connect to the machine and run the generator locally
echo "Connecting to $MACHINE to retrieve Vault keys..."
ssh "root@$MACHINE" 'cd /home/brittonr/git/onix-core && clan vars generate '"$MACHINE"' --generator vault-keys'

echo "Vault keys have been updated in clan vars!"
echo ""
echo "You can verify with:"
echo "  clan vars get $MACHINE vault-keys"