#!/usr/bin/env bash
# Setup script for Pico HSM with Vault

set -euo pipefail

echo "Pico HSM Setup for Vault"
echo "========================"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
   echo "Please run this script as a regular user (not root)"
   exit 1
fi

# Check for required tools
for cmd in pkcs11-tool pcsc_scan; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is not installed"
        echo "Install with: sudo apt-get install opensc pcscd pcsc-tools"
        exit 1
    fi
done

echo "Step 1: Checking for HSM devices..."
echo "-----------------------------------"
pcsc_scan -n || echo "No smartcard readers found. Make sure your Pico HSM is connected."

echo ""
echo "Step 2: Listing PKCS11 slots..."
echo "--------------------------------"
pkcs11-tool --module /usr/lib/opensc-pkcs11.so -L

echo ""
echo "Step 3: HSM PIN Setup"
echo "---------------------"
echo "The default PIN for Pico HSM is: 123456"
echo "The default SO-PIN is: 3537363231383830"
echo ""
read -p "Do you want to change the PIN? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Enter the current PIN (default: 123456):"
    read -rs CURRENT_PIN
    echo "Enter the new PIN (6-8 digits):"
    read -rs NEW_PIN
    echo "Confirm new PIN:"
    read -rs CONFIRM_PIN
    
    if [ "$NEW_PIN" != "$CONFIRM_PIN" ]; then
        echo "PINs do not match!"
        exit 1
    fi
    
    pkcs11-tool --module /usr/lib/opensc-pkcs11.so --change-pin --pin "$CURRENT_PIN" --new-pin "$NEW_PIN"
    echo "PIN changed successfully"
    HSM_PIN="$NEW_PIN"
else
    HSM_PIN="123456"
fi

echo ""
echo "Step 4: Create PIN file for Vault"
echo "----------------------------------"
echo "Creating PIN file at /tmp/hsm-pin.env"
echo "HSM_PIN=$HSM_PIN" > /tmp/hsm-pin.env
chmod 600 /tmp/hsm-pin.env

echo ""
echo "You'll need to copy this file to your target machine:"
echo "  scp /tmp/hsm-pin.env root@britton-fw:/etc/vault/"
echo ""
echo "Then ensure proper permissions:"
echo "  ssh root@britton-fw 'mkdir -p /etc/vault && chmod 700 /etc/vault && chmod 600 /etc/vault/hsm-pin.env'"

echo ""
echo "Step 5: Test HSM access"
echo "-----------------------"
echo "Testing login with PIN..."
if pkcs11-tool --module /usr/lib/opensc-pkcs11.so --login --pin "$HSM_PIN" -O &> /dev/null; then
    echo "✓ HSM login successful"
else
    echo "✗ HSM login failed"
    exit 1
fi

echo ""
echo "Step 6: Next steps"
echo "------------------"
echo "1. Copy the HSM PIN file to your Vault server"
echo "2. Update your Vault configuration to use vault-hsm instance"
echo "3. Deploy with: clan machines update <machine-name>"
echo "4. The HSM will generate the unseal key on first initialization"
echo ""
echo "To use with existing Vault (migration):"
echo "  - Use the vault-migrate-hsm configuration"
echo "  - Run: vault operator unseal -migrate"
echo "  - Enter your existing unseal keys when prompted"
echo ""
echo "Security notes:"
echo "  - After initial key generation, set generateKey = false"
echo "  - Keep the HSM physically secure"
echo "  - Consider backup HSMs for production"
echo "  - The Pico HSM has no tamper protection - use for dev/test only"

# Cleanup
rm -f /tmp/hsm-pin.env