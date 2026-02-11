{ config, pkgs, ... }:
{
  networking = {
    hostName = "britton-desktop";
    resolvconf.extraConfig = ''
      name_servers="1.1.1.1 8.8.8.8"
    '';
  };

  time.timeZone = "America/New_York";
  time.hardwareClockInLocalTime = true; # Prevent time sync issues with Windows

  nix.settings = {
    trusted-users = [
      "root"
      "brittonr"
    ];
    substituters = [ "https://cache.dataaturservice.se/spectrum/" ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "spectrum-os.org-2:foQk3r7t2VpRx92CaXb5ROyy/NBdRJQG2uX2XJMYZfU="
    ];
    # Enable experimental features for uid-range support
    experimental-features = [
      "auto-allocate-uids"
      "cgroups"
    ];
    auto-allocate-uids = true;
    # System features for NixOS container tests
    system-features = [
      "uid-range"
      "kvm"
      "nixos-test"
      "big-parallel"
    ];
  };

  boot = {
    kernelPackages = pkgs.linuxPackages_6_18;
    # DisplayLink support for Wayland (evdi module)
    extraModulePackages = [ config.boot.kernelPackages.evdi ];
    kernelModules = [ "evdi" ];
    loader = {
      timeout = 1;
      grub = {
        timeoutStyle = "menu";
        enable = true;
        device = "nodev";
        efiSupport = true;
        useOSProber = true;
        configurationLimit = 5;
        extraConfig = ''
          GRUB_DISABLE_OS_PROBER=false
        '';
        extraEntries = ''
          menuentry "Reboot" {
            reboot
          }
        '';
      };
    };
  };

  services = {
    # Qualcomm EDL mode access
    udev.extraRules = ''
      SUBSYSTEM=="usb", ATTRS{idVendor}=="05c6", ATTRS{idProduct}=="9008", MODE="0666"
      SUBSYSTEM=="block", ENV{ID_VENDOR_ID}=="1949", ENV{ID_MODEL_ID}=="0324", TAG+="uaccess"
    '';

    printing.enable = true;

  };

  security.pam.services = {
    sudo.fprintAuth = false;
    # PAM services for desktop login (normally from greeter tag)
    login.enableGnomeKeyring = true;
    greetd.enableGnomeKeyring = true;
    hyprlock = { };
  };

  # Gnome keyring for SSH agent and secrets
  services.gnome.gnome-keyring.enable = true;

  # DisplayLink Manager service
  systemd.services.dlm = {
    description = "DisplayLink Manager Service";
    after = [ "display-manager.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.displaylink}/bin/DisplayLinkManager";
      Restart = "always";
      RestartSec = 5;
      LogsDirectory = "displaylink";
    };
  };

  programs.fuse.userAllowOther = true;

  environment.systemPackages = with pkgs; [
    imagemagick
    os-prober
    nirius
    displaylink
  ];
}
