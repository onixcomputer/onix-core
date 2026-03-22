#!/usr/bin/env bash
# Bootstrap a cloud-hypervisor guest disk image.
#
# Creates a raw ext4 disk image, installs the guest's NixOS system,
# and populates SSH host keys from clan vars.
#
# Usage: bootstrap.sh <machine-name> [disk-path] [disk-size]
#
# Requires: root (for mount/nixos-install), nix, the flake must be buildable.
set -euo pipefail

MACHINE="${1:?Usage: bootstrap.sh <machine-name> [disk-path] [disk-size]}"
DISK_PATH="${2:-/var/lib/cloud-hypervisor/${MACHINE}.img}"
DISK_SIZE="${3:-40G}"

FLAKE_ROOT="$(git -C "$(dirname "$0")/../.." rev-parse --show-toplevel)"

echo "=== Cloud Hypervisor Guest Bootstrap ==="
echo "  Machine:  $MACHINE"
echo "  Disk:     $DISK_PATH"
echo "  Size:     $DISK_SIZE"
echo "  Flake:    $FLAKE_ROOT"
echo

# --- Build the guest system ---
echo "Building guest NixOS system..."
TOPLEVEL=$(nix build "${FLAKE_ROOT}#nixosConfigurations.${MACHINE}.config.system.build.toplevel" --no-link --print-out-paths)
echo "  toplevel: $TOPLEVEL"

# --- Create disk image ---
mkdir -p "$(dirname "$DISK_PATH")"
if [[ -f $DISK_PATH ]]; then
  echo "ERROR: Disk image already exists: $DISK_PATH"
  echo "  Remove it first if you want to re-bootstrap."
  exit 1
fi

echo "Creating ${DISK_SIZE} raw disk image..."
truncate -s "$DISK_SIZE" "$DISK_PATH"
mkfs.ext4 -L nixos "$DISK_PATH"

# --- Mount and install ---
MNT=$(mktemp -d)
trap 'umount -R "$MNT" 2>/dev/null || true; rmdir "$MNT" 2>/dev/null || true' EXIT

echo "Mounting disk image..."
mount -o loop "$DISK_PATH" "$MNT"

echo "Installing NixOS system..."
nixos-install --root "$MNT" --system "$TOPLEVEL" --no-root-password --no-channel-copy

# --- Copy SSH host keys from clan vars ---
VARS_DIR="${FLAKE_ROOT}/vars/per-machine/${MACHINE}"
SSH_DIR="${MNT}/etc/ssh"
mkdir -p "$SSH_DIR"

if [[ -d "${VARS_DIR}/openssh" ]]; then
  echo "Installing SSH host keys from clan vars..."
  # The public key is plaintext; the private key is SOPS-encrypted.
  # For bootstrap, we need the decrypted private key.
  # sops-install-secrets handles this at boot, so we just need the public key
  # for known_hosts and the private key will be provisioned by sops on first boot.
  if [[ -f "${VARS_DIR}/openssh/ssh.id_ed25519.pub/value" ]]; then
    cp "${VARS_DIR}/openssh/ssh.id_ed25519.pub/value" "${SSH_DIR}/ssh_host_ed25519_key.pub"
    echo "  Installed ssh_host_ed25519_key.pub"
  fi
fi

# --- Ensure deployer can SSH in ---
# Root's authorized_keys come from the NixOS config (already in $TOPLEVEL).
# The activation script sets them up on first boot.

echo "Syncing..."
sync

echo
echo "=== Bootstrap complete ==="
echo "  Disk image: $DISK_PATH"
echo "  Start the VM: systemctl start cloud-hypervisor-${MACHINE}"
echo "  Then: clan machines update ${MACHINE}"
