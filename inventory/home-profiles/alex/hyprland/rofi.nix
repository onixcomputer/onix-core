{ pkgs, config, ... }:
{
  # Create Tokyo Night theme for rofi
  xdg.configFile."rofi/tokyo-night.rasi".text = ''
    * {
      bg0:    #1a1b26;
      bg1:    #24283b;
      bg2:    #414868;
      fg0:    #c0caf5;
      fg1:    #a9b1d6;
      accent: #7aa2f7;
      urgent: #f7768e;
      
      background-color: @bg0;
      text-color:       @fg0;
      font:             "CaskaydiaMono Nerd Font 12";
    }

    window {
      background-color: @bg0;
      border:           2px;
      border-color:     @accent;
      border-radius:    10px;
      width:            600px;
      padding:          0;
    }

    mainbox {
      background-color: transparent;
      children:         [inputbar, listview];
      spacing:          0;
    }

    inputbar {
      background-color: @bg1;
      text-color:       @fg0;
      padding:          12px;
      border-radius:    10px 10px 0 0;
      children:         [prompt, entry];
    }

    prompt {
      background-color: transparent;
      text-color:       @accent;
      padding:          0 8px 0 0;
    }

    entry {
      background-color: transparent;
      text-color:       @fg0;
      placeholder:      "Search...";
      placeholder-color: @fg1;
    }

    listview {
      background-color: transparent;
      padding:          8px;
      spacing:          4px;
      lines:            8;
      scrollbar:        false;
    }

    element {
      background-color: transparent;
      text-color:       @fg0;
      padding:          8px 12px;
      border-radius:    6px;
    }

    element selected {
      background-color: @bg2;
      text-color:       @accent;
    }

    element-text {
      background-color: transparent;
      text-color:       inherit;
    }

    element-icon {
      background-color: transparent;
      size:             24px;
      padding:          0 8px 0 0;
    }
  '';

  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland; # Wayland-native fork

    font = "CaskaydiaMono Nerd Font 12";
    terminal = "alacritty";
    theme = "${config.xdg.configHome}/rofi/tokyo-night.rasi";

    extraConfig = {
      modi = "drun,run,window,ssh";
      show-icons = true;
      icon-theme = "Papirus-Dark";
      display-drun = "Apps";
      display-run = "Run";
      display-window = "Windows";
      display-ssh = "SSH";
    };
  };

  # Add rofi scripts
  home.packages = with pkgs; [
    # Network manager for rofi
    (writeShellScriptBin "rofi-network" ''
      # Simple network menu using nmcli
      chosen=$(nmcli -t -f NAME connection show | ${rofi-wayland}/bin/rofi -dmenu -p "Network" -theme-str 'window {width: 400px;}')
      [ -z "$chosen" ] && exit

      # Connect to the chosen network
      nmcli connection up "$chosen" || {
        # If connection fails, might need password
        ${rofi-wayland}/bin/rofi -e "Failed to connect. Use nmtui for new networks."
      }
    '')

    # Power menu (replacing wofi-power)
    (writeShellScriptBin "rofi-power" ''
      entries="⇠ Logout\n⭮ Reboot\n⏻ Shutdown"

      selected=$(echo -e "$entries" | ${rofi-wayland}/bin/rofi -dmenu -p "Power" -theme-str 'window {width: 250px;} listview {lines: 3;}')

      case $selected in
        *Logout)
          ${hyprland}/bin/hyprctl dispatch exit;;
        *Reboot)
          systemctl reboot;;
        *Shutdown)
          systemctl poweroff -i;;
      esac
    '')

    # WiFi selector with better functionality
    (writeShellScriptBin "rofi-wifi" ''
      # Get list of available wifi networks
      nmcli dev wifi rescan 2>/dev/null

      networks=$(nmcli -f SSID,SIGNAL,BARS,SECURITY dev wifi list | tail -n +2)
      chosen=$(echo "$networks" | ${rofi-wayland}/bin/rofi -dmenu -p "WiFi" -theme-str 'window {width: 600px;}')

      [ -z "$chosen" ] && exit

      ssid=$(echo "$chosen" | awk '{print $1}')

      # Try to connect
      nmcli dev wifi connect "$ssid" || {
        # Need password
        password=$(${rofi-wayland}/bin/rofi -dmenu -p "Password for $ssid" -password)
        [ -z "$password" ] && exit
        nmcli dev wifi connect "$ssid" password "$password"
      }
    '')
  ];
}
