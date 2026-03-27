# UTM VM — aarch64-linux NixOS running on britton-air (Apple Silicon)
# Provides a local Linux build host and test deployment target.
{
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./disko.nix
  ];

  time.timeZone = "America/New_York";
  nixpkgs.hostPlatform = "aarch64-linux";

  networking = {
    hostName = "utm-vm";
    firewall.enable = true;
    # Override nixos tag's NetworkManager default — a headless VM has no GUI
    # for NM and networkd is simpler for DHCP-only setups.
    useNetworkd = lib.mkForce true;
    networkmanager.enable = lib.mkForce false;
  };

  boot = {
    # systemd-boot for UEFI
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    # UTM/QEMU virtio drivers for paravirtualized I/O
    initrd.availableKernelModules = [
      "virtio_pci"
      "virtio_blk"
      "virtio_scsi"
      "virtio_net"
    ];

    # Serial console for headless UTM access
    kernelParams = [ "console=ttyAMA0,115200" ];
  };

  # systemd-networkd — DHCP on virtio NIC
  systemd.network = {
    enable = true;
    networks.ethernet = {
      matchConfig.Type = "ether";
      networkConfig = {
        DHCP = true;
        IPv6AcceptRA = true;
      };
    };
  };

  # Act as a remote builder — advertise capabilities
  nix.settings = {
    max-jobs = lib.mkDefault 4;
    system-features = [
      "kvm"
      "nixos-test"
      "big-parallel"
    ];
  };

  environment.systemPackages = with pkgs; [
    btop
    fd
    htop
    tmux
    tree
  ];

  # envfs FUSE causes "Freezing execution" under QEMU aarch64 VMs.
  services.envfs.enable = lib.mkForce false;

  # zram swap — no physical swap partition needed in a VM
  zramSwap.enable = true;

  system.stateVersion = "25.05";
}
