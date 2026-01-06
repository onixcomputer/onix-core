{ inputs, pkgs, ... }:
let
  grubWallpaper = pkgs.fetchurl {
    name = "nixos-grub-wallpaper.jpg";
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/nix-grub-2880x1920.jpg";
    sha256 = "sha256-Xu3KlpNMiZzS2fXYGGx0u0Qch7CoEus6ODwNVL4Bq4U=";
  };
in
{
  imports = [
    inputs.grub2-themes.nixosModules.default
    ./pmods/macrand.nix
  ];

  networking.hostName = "alex-fw";
  time.timeZone = "Asia/Bangkok";

  # GRUB wallpaper (theme from grub-theme tag)
  boot.loader = {
    grub.useOSProber = true;
    grub2-theme = {
      customResolution = "2880x1920";
      splashImage = grubWallpaper;
    };
  };

  # Remote builder configuration
  nix = {
    buildMachines = [
      {
        protocol = "ssh-ng";
        hostName = "leviathan.cymric-daggertooth.ts.net";
        systems = [ "x86_64-linux" ];
        maxJobs = 7;
        speedFactor = 20;
        supportedFeatures = [
          "nixos-test"
          "benchmark"
          "big-parallel"
          "kvm"
        ];
        mandatoryFeatures = [ ];
        sshUser = "alex";
      }
    ];
    settings.trusted-users = [
      "root"
      "alex"
    ];
  };

  # SSH agent forwarding for remote builds
  programs.ssh.extraConfig = ''
    Host leviathan.cymric-daggertooth.ts.net
      IdentityAgent /run/user/3801/gcr/ssh
  '';

  # AMD GPU (ROCm)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      mesa
      vulkan-loader
      libva
      rocmPackages.clr.icd
    ];
  };

  # VM building
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  services = {
    # Framework laptop fingerprint (disabled for sudo)
    fprintd.enable = true;

    # Framework firmware updates
    fwupd.enable = true;

    # Network printing support
    printing = {
      enable = true;
      browsing = true;
      defaultShared = false;
      drivers = with pkgs; [
        gutenprint
        hplip
        epson-escpr2
        brlaser
        splix
      ];
    };

    # Auto-configure network printers via Avahi
    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };
  };

  # Framework laptop fingerprint disabled for sudo
  security.pam.services.sudo.fprintAuth = false;

  environment.systemPackages = with pkgs; [
    os-prober
    signal-desktop
    prismlauncher
  ];
}
