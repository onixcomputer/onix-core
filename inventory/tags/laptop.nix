{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Battery percentage at which to auto-suspend while discharging.
  # Override per-machine with mkForce if needed.
  powerInPercent = 10;
in
{
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  programs.dconf.enable = true;

  # dbus-broker caches service file paths via inotify. When NixOS switches
  # generations, the inotify watches go stale and dbus-broker never discovers
  # new D-Bus services (like ca.desrt.dconf). Reload each logged-in user's
  # dbus-broker before home-manager activation so dconf.service is activatable.
  systemd.services =
    (lib.mapAttrs' (
      name: _:
      lib.nameValuePair "home-manager-${name}" {
        environment.XDG_DATA_DIRS = "/run/current-system/sw/share";
        preStart =
          let
            uid = toString config.users.users.${name}.uid;
          in
          ''
            # Reload user dbus-broker (same pattern as desktop.nix).
            for _i in 1 2 3 4; do
              if ${pkgs.procps}/bin/pkill -HUP -u ${uid} -x dbus-broker-lau 2>/dev/null; then
                break
              fi
              sleep 0.5
            done
          '';
      }
    ) config.home-manager.users)
    // {
      # Powertop aggressively suspends USB devices including keyboards/mice.
      # Re-enable all HID devices after auto-tune runs.
      powertop.postStart = ''
        HIDDEVICES=$(ls /sys/bus/usb/drivers/usbhid | grep -oE '^[0-9]+-[0-9\.]+' | sort -u)
        for i in $HIDDEVICES; do
          echo -n "Enabling " | cat - /sys/bus/usb/devices/$i/product
          echo 'on' > /sys/bus/usb/devices/$i/power/control
        done
      '';
      powertop.serviceConfig = {
        Restart = "on-failure";
        RestartSec = "2s";
      };
    };

  # Dynamic timezone — let NetworkManager dispatcher scripts handle
  # timezone changes automatically when traveling. No hardcoded zone.
  time.timeZone = null;
  services.automatic-timezoned.enable = true;

  # Faster WiFi reconnection and better power management
  networking.networkmanager.wifi.backend = "iwd";

  # Powertop auto-tune for battery life
  powerManagement.powertop.enable = true;

  services = {
    # High-performance D-Bus implementation (default on Arch/Fedora)
    dbus.implementation = "broker";

    # Auto-suspend at low battery — pure udev, no daemon or polling
    udev.extraRules = ''
      SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", ATTR{capacity}=="${toString powerInPercent}", RUN+="${config.systemd.package}/bin/systemctl suspend"
    '';

    xserver = {
      enable = true;
      xkb = {
        layout = "us";
        variant = "";
      };
    };
    blueman.enable = true;
    power-profiles-daemon.enable = true;
    upower.enable = true;

    libinput = {
      enable = true;
      touchpad = {
        tapping = true;
        disableWhileTyping = true;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    xdg-utils
    desktop-file-utils
    shared-mime-info
    brightnessctl
    powertop
    acpi
    libnotify
    bluetui # TUI Bluetooth device manager (scan, pair, connect)
  ];
}
