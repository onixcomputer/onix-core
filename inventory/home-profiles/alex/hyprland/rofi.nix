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

  home.packages = with pkgs; [
    # Unified network menu that handles both WiFi and Ethernet
    (writeShellScriptBin "rofi-network-menu" ''
      # Detect active connection type
      active_type=$(nmcli -t -f TYPE,STATE con show --active | grep activated | cut -d: -f1)

      if [ "$active_type" = "802-3-ethernet" ]; then
        # Ethernet is connected - show ethernet options
        menu="
          󰢾  Network Settings
          󰖩  Switch to WiFi

          󰈁  Ethernet Connected"

        chosen=$(echo -e "$menu" | ${rofi-wayland}/bin/rofi -dmenu -p "Network" \
          -theme-str 'window {width: 400px;} listview {lines: 4;}' \
          -theme-str 'element {font: "CaskaydiaMono Nerd Font 11";}')

        case "$chosen" in
          *"Network Settings")
            nm-connection-editor &
            ;;
          *"Switch to WiFi")
            rofi-wifi
            ;;
        esac
      else
        # WiFi or disconnected - show WiFi menu
        rofi-wifi
      fi
    '')

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

    (writeShellScriptBin "rofi-power" ''
      entries="⇠ Logout\n⭮ Reboot\n⏻ Shutdown"

      selected=$(echo -e "$entries" | ${rofi-wayland}/bin/rofi -dmenu -p "Power" \
        -theme-str 'window {width: 250px;} listview {lines: 3;}' \
        -theme-str 'element {font: "CaskaydiaMono Nerd Font 11";}')

      case $selected in
        *Logout)
          ${hyprland}/bin/hyprctl dispatch exit;;
        *Reboot)
          systemctl reboot;;
        *Shutdown)
          systemctl poweroff -i;;
      esac
    '')

    (writeShellScriptBin "rofi-wifi" ''
            # Check if WiFi is enabled
            wifi_status=$(nmcli radio wifi)
            # Menu options
            if [ "$wifi_status" = "enabled" ]; then
              toggle_text="󰖪  Disable WiFi"
            else
              toggle_text="󰖩  Enable WiFi"
            fi

            # Add special menu items at the top
            menu_items="󰢾  Network Settings
      $toggle_text"

            # Only scan if WiFi is enabled
            if [ "$wifi_status" = "enabled" ]; then
              nmcli dev wifi rescan 2>/dev/null
              # Filter out hidden networks (empty SSID) and duplicates
              networks=$(nmcli -f SSID,SIGNAL,BARS,SECURITY dev wifi list | tail -n +2 | grep -v '^--' | awk '!seen[$1]++ && $1 != ""' | head -20)
              if [ -n "$networks" ]; then
                full_menu=$(echo -e "$menu_items\n\n$networks")
              else
                full_menu="$menu_items"
              fi
            else
              full_menu="$menu_items"
            fi

            chosen=$(echo -e "$full_menu" | ${rofi-wayland}/bin/rofi -dmenu -p "Network" \
              -theme-str 'window {width: 600px;} listview {lines: 12;}' \
              -theme-str 'element {font: "CaskaydiaMono Nerd Font 11";}')

            [ -z "$chosen" ] && exit

            case "$chosen" in
              *"Network Settings")
                nm-connection-editor &
                ;;
              *"Enable WiFi")
                nmcli radio wifi on
                notify-send "WiFi" "WiFi enabled" -i network-wireless
                ;;
              *"Disable WiFi")
                nmcli radio wifi off
                notify-send "WiFi" "WiFi disabled" -i network-wireless-disconnected
                ;;
              *)
                # Connecting to a network
                ssid=$(echo "$chosen" | awk '{print $1}')

                # Just try to connect - let gnome-keyring handle passwords
                nmcli dev wifi connect "$ssid" && {
                  notify-send "WiFi" "Connected to $ssid" -i network-wireless
                } || {
                  notify-send "WiFi" "Could not connect to $ssid" -i dialog-information
                }
                ;;
            esac
    '')
  ];
}
