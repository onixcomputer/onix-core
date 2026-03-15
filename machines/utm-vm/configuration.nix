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
    # Override all tag's NetworkManager default — a headless VM has no GUI
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

  # Nix settings — act as a remote builder
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        "brittonr"
      ];
      max-jobs = lib.mkDefault 4;
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = lib.mkForce "--delete-older-than 14d";
    };
  };

  # Users
  users.users.brittonr = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYzh3yIsSTOYXkJMFHBKzkakoDfonm3/RED5rqMqhIO britton@framework"
    ];
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYzh3yIsSTOYXkJMFHBKzkakoDfonm3/RED5rqMqhIO britton@framework"
  ];
  # SSH server — primary access method
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  # Useful packages for a build host
  environment.systemPackages = with pkgs; [
    btop
    fd
    git
    htop
    jq
    ripgrep
    tmux
    tree
    vim
  ];

  # envfs FUSE causes "Freezing execution" under QEMU aarch64 VMs.
  # Mic92 hit the same issue. Disable it.
  services.envfs.enable = lib.mkForce false;

  # zram swap — no physical swap partition needed in a VM
  zramSwap.enable = true;

  system.stateVersion = "25.05";
}
