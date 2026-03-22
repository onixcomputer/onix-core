# Cloud Hypervisor Guest — NixOS configuration for VMs running under cloud-hypervisor.
#
# Direct kernel boot (no bootloader), virtio paravirtualized I/O,
# systemd-networkd DHCP, serial console on ttyS0.
# Designed for headless clan-managed machines deployed via SSH.
{ lib, ... }:
{
  # --- Boot ---

  boot = {
    # No bootloader — cloud-hypervisor does direct kernel boot via --kernel/--initramfs.
    loader.grub.enable = false;

    # systemd-in-initrd for faster boot and better error handling.
    initrd = {
      systemd.enable = true;
      availableKernelModules = [
        "virtio_pci"
        "virtio_blk"
        "virtio_net"
        "virtio_console"
      ];
    };

    kernelParams = [
      # Serial console for cloud-hypervisor --serial tty.
      "console=ttyS0,115200"
      # Skip fsck — cloud-hypervisor rejects writes to sector 0 of raw disk images,
      # which breaks e2fsck superblock repair. Run e2fsck from the host if needed.
      "fsck.mode=skip"
    ];
  };

  # --- Networking ---

  networking = {
    # systemd-networkd, not NetworkManager — headless VM, no GUI.
    useNetworkd = lib.mkForce true;
    networkmanager.enable = lib.mkForce false;
  };

  systemd.network = {
    enable = true;
    networks."10-virtio" = {
      matchConfig = {
        # Match by kernel driver, not interface name. Name depends on
        # cloud-hypervisor's PCI slot assignment (ens2, enp0s3, etc.)
        # and can change if devices are reordered.
        Driver = "virtio_net";
      };
      networkConfig = {
        DHCP = "yes";
        IPv6AcceptRA = true;
        # Start DHCP even before carrier is detected. Handles the timing
        # race where the TAP is UP on the host but the guest's virtio-net
        # hasn't reported carrier yet.
        ConfigureWithoutCarrier = true;
      };
      linkConfig = {
        # Force the interface administratively UP regardless of carrier state.
        # Without this, networkd may leave the interface DOWN if carrier
        # detection is delayed during virtio-net initialization.
        ActivationPolicy = "up";
      };
    };
  };

  # Avoid boot hangs — systemd bug #29388 causes networkd-wait-online
  # to stall indefinitely in VMs.
  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;

  # --- Services ---

  # envfs FUSE is broken under cloud-hypervisor / QEMU guests.
  services.envfs.enable = lib.mkForce false;

  # --- Nix GC ---

  # Aggressive GC to keep the fixed-size disk image from filling up.
  nix.gc = {
    automatic = true;
    dates = lib.mkForce "daily";
    options = lib.mkForce "--delete-older-than 7d";
  };
}
