#!/usr/bin/env bash
# Check if Pico HSM is connected locally

echo "Checking for Pico HSM on local machine..."
echo "======================================="
echo ""

# Try to run in a nix-shell with required packages
nix-shell -p pcsclite pcsctools opensc --run '
echo "1. Checking PC/SC daemon status:"
if pgrep pcscd > /dev/null; then
    echo "   ✓ pcscd is running"
else
    echo "   ✗ pcscd is not running"
    echo "   Starting pcscd..."
    sudo systemctl start pcscd 2>/dev/null || sudo pcscd || echo "Failed to start pcscd"
fi

echo ""
echo "2. Scanning for smart card readers:"
pcsc_scan -n || echo "No readers found"

echo ""
echo "3. Listing PKCS11 slots:"
pkcs11-tool --module /run/current-system/sw/lib/opensc-pkcs11.so -L 2>/dev/null || \
pkcs11-tool --module /usr/lib/opensc-pkcs11.so -L 2>/dev/null || \
echo "Could not find opensc-pkcs11.so"

echo ""
echo "4. Checking USB devices (requires root):"
sudo lsusb 2>/dev/null | grep -E "(Pico|HSM|Smart|1050|20a0)" || echo "No HSM devices found in USB list"
'

echo ""
echo "If the Pico HSM is not detected:"
echo "1. Make sure it's properly connected via USB"
echo "2. Check if you need to install Pico HSM firmware"
echo "3. Try unplugging and reconnecting the device"
echo ""
echo "For Pico HSM specifically, the device should show up as:"
echo "- A CCID-compatible smart card reader"
echo "- USB VID:PID might be something like 20a0:42XX"