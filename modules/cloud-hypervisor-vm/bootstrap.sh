#!/usr/bin/env bash
# Bootstrap a cloud-hypervisor guest disk image.
#
# Creates a GPT-partitioned raw disk image using disko, then installs
# the guest's NixOS system with nixos-install.
#
# Usage: bootstrap.sh <machine-name> [disk-path] [disk-size]
#
# Requires: root, nix, sgdisk, mkfs.ext4
set -euo pipefail

MACHINE="${1:?Usage: bootstrap.sh <machine-name> [disk-path] [disk-size]}"
DISK_PATH="${2:-/var/lib/cloud-hypervisor/${MACHINE}.img}"
DISK_SIZE="${3:-40G}"

FLAKE_ROOT="$(git -C "$(dirname "$0")/../.." rev-parse --show-toplevel)"

echo "=== Cloud Hypervisor Guest Bootstrap ==="
echo "  Machine:  $MACHINE"
echo "  Disk:     $DISK_PATH"
echo "  Size:     $DISK_SIZE"
echo

# --- Build the guest system ---
echo "Building guest NixOS system..."
TOPLEVEL=$(nix build "${FLAKE_ROOT}#nixosConfigurations.${MACHINE}.config.system.build.toplevel" --no-link --print-out-paths)
echo "  toplevel: $TOPLEVEL"

# --- Create disk image ---
mkdir -p "$(dirname "$DISK_PATH")"
if [[ -f $DISK_PATH ]]; then
  echo "ERROR: Disk image already exists: $DISK_PATH"
  echo "  Remove it first to re-bootstrap."
  exit 1
fi

echo "Creating ${DISK_SIZE} disk image with GPT partition..."
truncate -s "$DISK_SIZE" "$DISK_PATH"

# Set up loop device
LOOP=$(losetup --find --show "$DISK_PATH")
trap 'umount -R /tmp/chv-bootstrap 2>/dev/null || true; losetup -d "$LOOP" 2>/dev/null || true; rmdir /tmp/chv-bootstrap 2>/dev/null || true' EXIT

# Create GPT with one partition spanning the whole disk
sgdisk --clear "$LOOP"
sgdisk --new=1:0:0 --change-name=1:disk-main-root --typecode=1:8300 "$LOOP"
partprobe "$LOOP" 2>/dev/null || true
sleep 1

# Find the partition device
PART="${LOOP}p1"
if [[ ! -b $PART ]]; then
  # Some systems use a different naming
  partx -a "$LOOP" 2>/dev/null || true
  sleep 1
fi

if [[ ! -b $PART ]]; then
  echo "ERROR: Partition device $PART not found"
  exit 1
fi

echo "Formatting partition..."
mkfs.ext4 -L nixos "$PART"

# --- Mount and install ---
MNT=/tmp/chv-bootstrap
mkdir -p "$MNT"
mount "$PART" "$MNT"

echo "Installing NixOS system..."
nixos-install --root "$MNT" --system "$TOPLEVEL" --no-root-password --no-channel-copy

# Generate machine-id. Without this, systemd-networkd's DHCPv4 client
# fails with ENOENT because it needs machine-id for DUID generation.
# nixos-install in a chroot can't create it when /etc/ is read-only
# (nix store overlay), so we create it explicitly.
echo "Generating machine-id..."
systemd-id128 new >"$MNT/etc/machine-id"
chmod 444 "$MNT/etc/machine-id"

echo "Syncing..."
sync

echo
echo "=== Bootstrap complete ==="
echo "  Disk image: $DISK_PATH"
echo "  Start the VM: systemctl start cloud-hypervisor-${MACHINE}"
echo "  Then: clan machines update ${MACHINE}"
