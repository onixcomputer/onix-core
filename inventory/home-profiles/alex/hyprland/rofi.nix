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
      # Power menu with 4 options
      lock="󰌾  Lock"
      logout="󰍃  Logout"  
      shutdown="󰐥  Shutdown"
      reboot="󰜉  Reboot"

      # Show menu without search bar
      selected=$(echo -e "$lock\n$logout\n$shutdown\n$reboot" | \
        ${rofi-wayland}/bin/rofi -dmenu -p "Power" \
        -theme-str 'entry { enabled: false; }' \
        -theme-str 'window { width: 300px; }' \
        -theme-str 'listview { lines: 4; }' \
        -theme-str 'inputbar { children: [prompt]; }' \
        -theme-str 'prompt { text-color: #7aa2f7; }')

      case "$selected" in
        "$lock")
          hyprlock;;
        "$logout")
          hyprctl dispatch exit 0;;
        "$shutdown")
          systemctl poweroff;;
        "$reboot")
          systemctl reboot;;
      esac
    '')

    # Fast WiFi menu with live network list
    (writeShellScriptBin "rofi-wifi" ''
            # Get WiFi status
            wifi_status=$(nmcli radio wifi)
            
            # Build menu options
            if [ "$wifi_status" = "enabled" ]; then
              toggle_text="󰖪  Disable WiFi"
              
              # Get current connection
              current=$(nmcli -t -f NAME,TYPE con show --active | grep wireless | cut -d: -f1)
              
              # Get ALL available networks (cached by NetworkManager, should be fast)
              # Format: SSID:Signal:Security:InUse
              networks=$(nmcli -t -f SSID,SIGNAL,SECURITY,IN-USE dev wifi | \
                grep -v '^--' | \
                awk -F: '$1 != "" {
                  icon = $4 == "*" ? "󰸞" : ($3 ~ /WPA|WEP/ ? "󰌾" : "󰌿")
                  printf "%s  %-20s %3s%% %s\n", icon, substr($1,1,20), $2, $3
                }' | \
                sort -k3 -rn | head -20)
              
            else
              toggle_text="󰖩  Enable WiFi"
              networks="WiFi is disabled"
            fi

            # Build menu
            menu_items="󰢾  Network Settings
      $toggle_text
      󰑓  Refresh"
            
            if [ -n "$networks" ]; then
              menu_items="$menu_items

      $networks"
            fi

            chosen=$(echo "$menu_items" | ${rofi-wayland}/bin/rofi -dmenu -p "WiFi" \
              -theme-str 'window {width: 600px;}' \
              -theme-str 'listview {lines: 15;}' \
              -theme-str 'element {font: "CaskaydiaMono Nerd Font 11";}')

            [ -z "$chosen" ] && exit

            case "$chosen" in
              *"Network Settings")
                nm-connection-editor &
                ;;
              *"Refresh")
                # Force rescan and reopen menu
                notify-send -t 1000 "WiFi 󰑓" "Refreshing networks..."
                nmcli dev wifi rescan 2>/dev/null &
                sleep 0.5
                exec rofi-wifi
                ;;
              *"Enable WiFi")
                nmcli radio wifi on
                notify-send "WiFi" "WiFi enabled" -i network-wireless
                sleep 1
                exec rofi-wifi
                ;;
              *"Disable WiFi")
                nmcli radio wifi off
                notify-send "WiFi" "WiFi disabled" -i network-wireless-disconnected
                ;;
              "󰸞  "*)
                # Already connected - do nothing
                ;;
              "󰌾  "*|"󰌿  "*)
                # Extract SSID from the chosen line (handle both locked and open networks)
                ssid=$(echo "$chosen" | sed 's/^[󰸞󰌾󰌿]  //' | awk '{print $1}')
                
                # Try to connect
                nmcli dev wifi connect "$ssid" 2>/dev/null && {
                  notify-send "WiFi" "Connected to $ssid" -i network-wireless
                } || {
                  notify-send "WiFi" "Could not connect to $ssid" -i dialog-information
                }
                ;;
            esac
    '')
  ];
}
