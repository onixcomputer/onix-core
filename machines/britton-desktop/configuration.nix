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
    kernel.sysctl."kernel.perf_event_paranoid" = -1;
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
    # Override greeter session for niri
    greetd.settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd /etc/profiles/per-user/brittonr/bin/niri-session";

    # Qualcomm EDL mode access
    udev.extraRules = ''
      SUBSYSTEM=="usb", ATTRS{idVendor}=="05c6", ATTRS{idProduct}=="9008", MODE="0666"
      SUBSYSTEM=="block", ENV{ID_VENDOR_ID}=="1949", ENV{ID_MODEL_ID}=="0324", TAG+="uaccess"
      # Rockchip Maskrom/Loader
      SUBSYSTEM=="usb", ATTR{idVendor}=="2207", MODE="0660", GROUP="wheel"
      # SDWire (Realtek card reader with mux control)
      SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="0316", MODE="0660", GROUP="wheel"
    '';

    printing.enable = true;

  };

  security.pam.services = {
    sudo.fprintAuth = false;
    # PAM services for desktop login (normally from greeter tag)
    login.enableGnomeKeyring = true;
    greetd.enableGnomeKeyring = true;
    # hyprlock = { }; # Removed: using noctalia lock screen with niri
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

  security.sudo.extraRules = [
    {
      users = [ "brittonr" ];
      commands = [
        {
          command = "${pkgs.bpftrace}/bin/bpftrace";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/home/brittonr/.cargo-target/release/chaoscontrol-trace";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  environment.systemPackages = with pkgs; [
    bpftrace
    imagemagick
    os-prober
    nirius
    displaylink
  ];
}
