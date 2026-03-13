{
  config,
  lib,
  pkgs,
  ...
}:
{
  # fhs-compat now applied to all NixOS machines via nixos.nix
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # High-performance D-Bus implementation (default on Arch/Fedora)
  services.dbus.implementation = "broker";

  programs.dconf.enable = true;

  # dbus-broker caches service file paths from /run/current-system/sw via
  # inotify. When NixOS atomically switches the symlink to a new store path,
  # dbus-broker's inotify watches go stale and it never discovers new D-Bus
  # services (like ca.desrt.dconf). Reload each logged-in user's dbus-broker
  # before home-manager activation so dconf.service becomes activatable.
  systemd.services = lib.mapAttrs' (
    name: _:
    lib.nameValuePair "home-manager-${name}" {
      environment.XDG_DATA_DIRS = "/run/current-system/sw/share";
      preStart =
        let
          uid = toString config.users.users.${name}.uid;
        in
        ''
          # Reload user dbus-broker so it re-reads service files from new
          # /run/current-system/sw store path. SIGHUP triggers config reload
          # in dbus-broker-launch.
          ${pkgs.procps}/bin/pkill -HUP -u ${uid} -x dbus-broker-lau 2>/dev/null || true
          sleep 0.5
        '';
    }
  ) config.home-manager.users;

  services = {
    xserver = {
      enable = true;
      xkb = {
        layout = "us";
        variant = "";
      };
    };
    blueman.enable = true;

    libinput = {
      enable = true;
      touchpad = {
        tapping = true;
        naturalScrolling = true;
        disableWhileTyping = false;
      };
    };
  };

  environment.systemPackages = with pkgs; [
    xdg-utils
    desktop-file-utils
    shared-mime-info
    powertop
    acpi
  ];
}
