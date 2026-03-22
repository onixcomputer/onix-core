{
  config,
  lib,
  pkgs,
  ...
}:
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
        configurationLimit = 5;
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

  security = {
    pam.services = {
      sudo.fprintAuth = false;
    };

    # srvos sets security.sudo.execWheelOnly = true, which asserts that
    # extraRules only reference root/wheel. We need per-user rules here,
    # so disable it on this machine.
    sudo.execWheelOnly = lib.mkForce false;

    sudo.extraRules = [
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
  };

  systemd = {
    # DisplayLink Manager service
    services.dlm = {
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

    # Prevent suspend/sleep entirely — this machine should always stay on
    targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };
  };

  programs.fuse.userAllowOther = true;

  environment.systemPackages = with pkgs; [
    bpftrace
    imagemagick
    nirius
    displaylink
  ];
}
