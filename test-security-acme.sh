#!/usr/bin/env bash
# Test deployment script for security-acme service on britton-fw

set -euo pipefail

echo "=== Security ACME Test Deployment ==="
echo "This script will help test the security-acme service on britton-fw"
echo

# Check if we're in the right directory
if [ ! -f "flake.nix" ]; then
    echo "Error: Please run this script from the onix-core root directory"
    exit 1
fi

echo "1. First, let's check the current configuration:"
echo "   - Provider: britton-fw"
echo "   - Wildcard domain: *.onix.computer"
echo "   - Using existing tailscale-traefik Cloudflare credentials"
echo

echo "2. Build the configuration for britton-fw:"
echo "   Run: nix build .#nixosConfigurations.britton-fw.config.system.build.toplevel"
echo

echo "3. Deploy to britton-fw:"
echo "   Run: clan machines update britton-fw"
echo "   OR if you prefer colmena: colmena apply --on britton-fw"
echo

echo "4. After deployment, check the ACME service status on britton-fw:"
echo "   ssh root@britton-fw 'systemctl status acme-\\*.onix.computer.service'"
echo "   ssh root@britton-fw 'journalctl -u acme-\\*.onix.computer.service -f'"
echo

echo "5. Check certificate generation:"
echo "   ssh root@britton-fw 'ls -la /var/lib/acme/'"
echo

echo "6. Check certificate sync service:"
echo "   ssh root@britton-fw 'systemctl status sync-acme-certs.service'"
echo "   ssh root@britton-fw 'journalctl -u sync-acme-certs.service'"
echo

echo "7. Manually trigger certificate sync (if needed):"
echo "   ssh root@britton-fw 'systemctl start sync-acme-certs.service'"
echo

echo "8. Check if certificates are in clan vars:"
echo "   clan vars list | grep -E '(wildcard|onix.computer)'"
echo

echo "=== Troubleshooting ==="
echo "If the ACME service fails:"
echo "- Check Cloudflare credentials: clan vars show tailscale-traefik"
echo "- Verify DNS propagation: dig TXT _acme-challenge.onix.computer"
echo "- Check firewall isn't blocking outbound HTTPS"
echo

echo "=== Integration with Services ==="
echo "Once certificates are generated, you can:"
echo "1. Configure other machines as consumers to use the wildcard cert"
echo "2. Update Traefik to use the external certificate instead of built-in ACME"
echo "3. Use the certificate for any service needing *.onix.computer SSL"