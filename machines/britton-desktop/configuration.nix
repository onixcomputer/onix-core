{
  config,
  lib,
  pkgs,
  inputs,
  self,
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
    # Enable experimental features for uid-range support and Nix build cgroups.
    experimental-features = [
      "auto-allocate-uids"
      "cgroups"
    ];
    auto-allocate-uids = true;

    # Desktop-safe local Nix budget for the Ryzen 9 9950X3D:
    # 4 concurrent derivations × 4 build cores = 16 build threads, leaving
    # half of the 32 hardware threads schedulable for the compositor, browser,
    # editor, shells, and background services. Increase only for intentional
    # batch/off-hours builds or remote-builder-only workflows.
    max-jobs = 4;
    cores = 4;
    use-cgroups = true;

    # System features for NixOS container tests
    system-features = [
      "uid-range"
      "kvm"
      "nixos-test"
      "big-parallel"
    ];
  };

  # AMD 9950X3D: microcode updates + P-State active mode.
  # active mode lets firmware handle preferred-core ranking across the
  # asymmetric CCDs (3D V-Cache vs high-clock).
  hardware.cpu.amd.updateMicrocode = true;

  boot = {
    kernelParams = [ "amd_pstate=active" ];
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
      # Elgato Stream Deck (OpenDeck)
      SUBSYSTEM=="usb", ATTRS{idVendor}=="0fd9", MODE="0660", TAG+="uaccess"
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0fd9", MODE="0660", TAG+="uaccess"
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

    # Keep daemon-managed builds below interactive desktop work. Nix builds are
    # also capped by nix.settings max-jobs/cores above; these cgroup weights and
    # memory pressure guard protect the compositor/session when builds are busy.
    services.nix-daemon.serviceConfig = {
      CPUWeight = 25;
      IOWeight = 25;
      MemoryHigh = "140G";
    };
  };

  programs.fuse.userAllowOther = true;

  environment.systemPackages = with pkgs; [
    bpftrace
    imagemagick
    nirius
    prismlauncher
    displaylink
    self.packages.${pkgs.stdenv.hostPlatform.system}.opendeck
    self.packages.${pkgs.stdenv.hostPlatform.system}.ttsim
    inputs.nixpkgs-herdr.legacyPackages.${pkgs.stdenv.hostPlatform.system}.herdr
  ];

  # ZFS on the 4TB data drive
  networking.hostId = "07e6df3e";
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.extraPools = [ "datapool" ];

  # Put /tmp on the 4TB datapool instead of RAM-backed tmpfs, while keeping
  # classic scratch-directory semantics across boots.
  boot.tmp = {
    useTmpfs = false;
    cleanOnBoot = true;
  };
}
