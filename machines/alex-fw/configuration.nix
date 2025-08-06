{ inputs, pkgs, ... }:
let
  grubWallpaper = pkgs.fetchurl {
    name = "nixos-grub-wallpaper.jpg";
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/nix-grub-2880x1920.jpg";
    sha256 = "sha256-Xu3KlpNMiZzS2fXYGGx0u0Qch7CoEus6ODwNVL4Bq4U=";
  };
  streetWallpaper = pkgs.fetchurl {
    name = "street-wallpaper.png";
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/street-full.jpg";
    sha256 = "sha256-XlSm8RzGwowJMT/DQBNwfsU4V6QuvP4kvwVm1pzw6SM=";
  };
in
{
  imports = [
    inputs.grub2-themes.nixosModules.default
    inputs.sddm-sugar-candy-nix.nixosModules.default
  ];

  networking = {
    hostName = "alex-fw";
    networkmanager.enable = true;
  };

  time.timeZone = "America/Los_Angeles";

  environment.systemPackages = with pkgs; [
    imagemagick # required for grub2-theme
    claude-code
    comma

    #custom scripts
    (pkgs.writeShellScriptBin "randomize-mac" ''
      #!/bin/bash

      # Get the active WiFi connection
      WIFI_CONN=$(nmcli -t -f NAME,TYPE connection show --active | grep "802-11-wireless" | cut -d: -f1)

      if [ -z "$WIFI_CONN" ]; then
      echo "No active WiFi connection found"
      exit 1
      fi

      echo "Randomizing MAC for connection: $WIFI_CONN"

      # Set random MAC address
      nmcli connection modify "$WIFI_CONN" 802-11-wireless.cloned-mac-address random

      # Reconnect to apply changes
      nmcli connection down "$WIFI_CONN"
      sleep 2
      nmcli connection up "$WIFI_CONN"

      # Show new MAC
      echo "New MAC address:"
      ip link show | grep -A1 "wl" | grep "link/ether"
    '')

    (pkgs.writeShellScriptBin "reset-mac" ''
      #!/bin/bash

      # Get the active WiFi connection
      WIFI_CONN=$(nmcli -t -f NAME,TYPE connection show --active | grep "802-11-wireless" | cut -d: -f1)

      if [ -z "$WIFI_CONN" ]; then
      echo "No active WiFi connection found"
      exit 1
      fi

      echo "Resetting MAC to default for connection: $WIFI_CONN"

      # Remove the cloned MAC setting (reverts to hardware default)
      nmcli connection modify "$WIFI_CONN" 802-11-wireless.cloned-mac-address ""

      # Reconnect to apply changes
      nmcli connection down "$WIFI_CONN"
      sleep 2
      nmcli connection up "$WIFI_CONN"

      # Show current MAC
      echo "Reset to hardware MAC address:"
      ip link show | grep -A1 "wl" | grep "link/ether"
    '')

    (pkgs.writeShellScriptBin "show-mac" ''
      #!/bin/bash
      echo "Current MAC addresses:"
      ip link show | grep -A1 "wl" | grep "link/ether"

      echo -e "\nWiFi connection MAC settings:"
      nmcli -t -f NAME,TYPE connection show | grep "802-11-wireless" | while IFS=: read -r conn type; do
        MAC_SETTING=$(nmcli -t -f 802-11-wireless.cloned-mac-address connection show "$conn" 2>/dev/null | cut -d: -f2)
        echo "$conn: ''${MAC_SETTING:-none}"
      done
    '')

  ];

  home-manager.backupFileExtension = "backup";

  boot.loader = {
    timeout = 1;
    grub = {
      timeoutStyle = "menu";
    };
    grub2-theme = {
      enable = true;
      theme = "stylish";
      footer = true;
      customResolution = "2880x1920";
      splashImage = grubWallpaper;
    };
  };

  services = {
    gnome.gnome-keyring.enable = true;

    #custom tokyo night theme
    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      sugarCandyNix = {
        enable = true;
        settings = {
          Background = streetWallpaper;
          ScreenWidth = 2880;
          ScreenHeight = 1920;
          FormPosition = "left";
          HaveFormBackground = true;
          PartialBlur = true;

          MainColor = "white";
          AccentColor = "#668ac4";
          BackgroundColor = "#1a1b26";
          OverrideLoginButtonTextColor = "white";

          HeaderText = "";
          DateFormat = "dddd, MMMM d";
          HourFormat = "HH:mm";

          ForceLastUser = true;
          ForceHideCompletePassword = true;
          ForcePasswordFocus = true;
        };
      };
    };

    fwupd.enable = true; # framework bios/firmware updates
  };

  security.pam.services.sddm.enableGnomeKeyring = true;

  system.stateVersion = "25.05";
}
