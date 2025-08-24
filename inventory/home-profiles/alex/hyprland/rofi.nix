{
  pkgs,
  config,
  lib,
  ...
}:
let
  theme = config.theme.colors;
  # Remove # from hex colors
  c = color: lib.removePrefix "#" color;
in
{
  # Create dynamic theme for rofi based on active theme
  xdg.configFile."rofi/custom-theme.rasi".text = ''
    * {
      bg0:    #${c theme.bg};
      bg1:    #${c theme.bg_highlight};
      bg2:    #${c theme.border};
      fg0:    #${c theme.fg};
      fg1:    #${c theme.fg_dim};
      accent: #${c theme.accent};
      urgent: #${c theme.red};

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
      background-color: @accent;
      text-color:       @bg0;
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
    terminal = "kitty";
    theme = "${config.xdg.configHome}/rofi/custom-theme.rasi";

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

  home.packages =
    with pkgs;
    let
      inherit rofi-wayland;
    in
    [
      # rbw integration for password management
      rofi-rbw-wayland # Rofi frontend for Bitwarden (Wayland version)
      wl-clipboard # Wayland clipboard support
      wtype # Wayland typing tool

      # Wallpaper testing tool - for temporary testing only
      (writeShellScriptBin "wallpaper-testing" ''
        #!/usr/bin/env bash

        OVERRIDE_FILE="$HOME/.config/wallpaper/override"

        case "$1" in
          clear)
            rm -f "$OVERRIDE_FILE"
            echo "Cleared testing overrides. Using Nix defaults."
            ;;
          show)
            echo "=== Current Wallpaper Configuration ==="
            echo ""
            if [[ -f "$OVERRIDE_FILE" ]]; then
              echo "⚠️  TESTING OVERRIDE ACTIVE (will be cleared on rebuild):"
              source "$OVERRIDE_FILE"
            else
              echo "Using Nix configuration:"
              source "$HOME/.config/wallpaper/config" 2>/dev/null || echo "Config not found"
            fi
            echo ""
            echo "Resize Mode:        $RESIZE_MODE"
            echo "Video Mode:         $VIDEO_RESIZE_MODE"
            echo "Fill Color:         #$FILL_COLOR"
            echo "Filter:             $FILTER"
            echo "Transition:         $TRANSITION_TYPE"
            echo "Duration:           $TRANSITION_DURATION seconds"
            echo "FPS:                $TRANSITION_FPS"
            echo "Step:               $TRANSITION_STEP"
            echo "Angle:              $TRANSITION_ANGLE°"
            echo "Position:           $TRANSITION_POS"
            echo "Bezier:             $TRANSITION_BEZIER"
            echo "Wave:               $TRANSITION_WAVE"
            echo ""
            if [[ -f "$OVERRIDE_FILE" ]]; then
              echo "Run 'wallpaper-testing clear' to remove testing overrides"
            fi
            ;;
          help)
            echo "=== Wallpaper Configuration Options ==="
            echo ""
            echo "📐 RESIZE MODES (images/GIFs):"
            echo "  • crop    - Fill screen, may crop edges"
            echo "  • fit     - Show entire image with borders"
            echo "  • stretch - Stretch to fill (distorts)"
            echo "  • no      - Center without resizing"
            echo ""
            echo "🎬 VIDEO RESIZE MODES:"
            echo "  • crop - Fill screen (panscan 1.0)"
            echo "  • fit  - Show entire video (panscan 0.0)"
            echo ""
            echo "🎨 TRANSITION TYPES:"
            echo "  • none    - Instant switch (alias for simple with step 255)"
            echo "  • simple  - Basic fade (ignores duration)"
            echo "  • fade    - Bezier curve controlled fade"
            echo "  • left    - Slide from left to right"
            echo "  • right   - Slide from right to left"
            echo "  • top     - Slide from top to bottom"
            echo "  • bottom  - Slide from bottom to top"
            echo "  • wipe    - Diagonal wipe (uses angle)"
            echo "  • wave    - Wavy wipe (uses angle & wave)"
            echo "  • grow    - Growing circle (uses position)"
            echo "  • center  - Growing from center"
            echo "  • any     - Growing from random position"
            echo "  • outer   - Shrinking circle (uses position)"
            echo "  • random  - Random transition each time"
            echo ""
            echo "🎛️ ADDITIONAL PARAMETERS:"
            echo "  • Fill Color:  Hex color for padding (000000-FFFFFF)"
            echo "  • Filter:      Nearest (pixel art) or Lanczos3/Mitchell/CatmullRom/Bilinear"
            echo "  • Duration:    1-10 seconds (doesn't work with 'simple')"
            echo "  • FPS:         30-144 (match your monitor)"
            echo "  • Step:        2-255 (speed vs smoothness, 255=instant)"
            echo "  • Angle:       0-360° for wipe/wave (0=right→left, 90=top→bottom)"
            echo "  • Position:    center/top/left/right/bottom/corners or x,y coords"
            echo "  • Bezier:      x1,y1,x2,y2 for fade (use cubic-bezier.com)"
            echo "  • Wave:        width,height in pixels for wave effect"
            ;;
          set)
            # Parse named parameters for easier use
            shift
            for arg in "$@"; do
              case "$arg" in
                resize=*) NEW_RESIZE_MODE="''${arg#*=}" ;;
                video=*) NEW_VIDEO_RESIZE_MODE="''${arg#*=}" ;;
                fill=*) NEW_FILL_COLOR="''${arg#*=}" ;;
                filter=*) NEW_FILTER="''${arg#*=}" ;;
                transition=*) NEW_TRANSITION_TYPE="''${arg#*=}" ;;
                duration=*) NEW_TRANSITION_DURATION="''${arg#*=}" ;;
                fps=*) NEW_TRANSITION_FPS="''${arg#*=}" ;;
                step=*) NEW_TRANSITION_STEP="''${arg#*=}" ;;
                angle=*) NEW_TRANSITION_ANGLE="''${arg#*=}" ;;
                pos=*) NEW_TRANSITION_POS="''${arg#*=}" ;;
                bezier=*) NEW_TRANSITION_BEZIER="''${arg#*=}" ;;
                wave=*) NEW_TRANSITION_WAVE="''${arg#*=}" ;;
              esac
            done

            # Load current config as base
            source "$HOME/.config/wallpaper/config" 2>/dev/null

            # Write override with updated values (use new values if provided, else keep current)
            mkdir -p "$(dirname "$OVERRIDE_FILE")"
            cat > "$OVERRIDE_FILE" << EOF
        # Temporary wallpaper config override
        RESIZE_MODE=''${NEW_RESIZE_MODE:-$RESIZE_MODE}
        VIDEO_RESIZE_MODE=''${NEW_VIDEO_RESIZE_MODE:-$VIDEO_RESIZE_MODE}
        FILL_COLOR=''${NEW_FILL_COLOR:-$FILL_COLOR}
        FILTER=''${NEW_FILTER:-$FILTER}
        TRANSITION_TYPE=''${NEW_TRANSITION_TYPE:-$TRANSITION_TYPE}
        TRANSITION_DURATION=''${NEW_TRANSITION_DURATION:-$TRANSITION_DURATION}
        TRANSITION_FPS=''${NEW_TRANSITION_FPS:-$TRANSITION_FPS}
        TRANSITION_STEP=''${NEW_TRANSITION_STEP:-$TRANSITION_STEP}
        TRANSITION_ANGLE=''${NEW_TRANSITION_ANGLE:-$TRANSITION_ANGLE}
        TRANSITION_POS=''${NEW_TRANSITION_POS:-$TRANSITION_POS}
        TRANSITION_BEZIER=''${NEW_TRANSITION_BEZIER:-$TRANSITION_BEZIER}
        TRANSITION_WAVE=''${NEW_TRANSITION_WAVE:-$TRANSITION_WAVE}
        EOF
            echo "Testing override created. Run 'wallpaper-testing show' to see current values."
            echo "⚠️  TEMPORARY: These settings will be cleared on next system rebuild."
            echo "For permanent changes, edit wallpaper.nix and rebuild."
            ;;
          *)
            echo "Usage: wallpaper-testing <command> [options]"
            echo ""
            echo "Commands:"
            echo "  show   - Display current configuration values"
            echo "  help   - Show all available options and parameters"
            echo "  set    - Create TEMPORARY testing override"
            echo "  clear  - Remove testing overrides, use Nix defaults"
            echo ""
            echo "Set command uses named parameters:"
            echo "  wallpaper-testing set <param>=<value> ..."
            echo ""
            echo "Parameters:"
            echo "  resize=<mode>       transition=<type>    angle=<degrees>"
            echo "  video=<mode>        duration=<seconds>   pos=<position>"
            echo "  fill=<color>        fps=<rate>           bezier=<curve>"
            echo "  filter=<type>       step=<value>         wave=<w,h>"
            echo ""
            echo "Examples:"
            echo "  wallpaper-testing show                              # Current config"
            echo "  wallpaper-testing help                              # All options"
            echo "  wallpaper-testing set transition=wave duration=5    # Test wave"
            echo "  wallpaper-testing set resize=fit fill=1a1b26        # Dark padding"
            echo "  wallpaper-testing set filter=Nearest                # Pixel art mode"
            echo "  wallpaper-testing clear                             # Reset to Nix"
            echo ""
            echo "⚠️  NOTE: This is for TESTING ONLY. All settings will be cleared on rebuild."
            echo "For permanent changes, edit wallpaper.nix and rebuild your system."
            ;;
        esac
      '')

      # Wallpaper restoration script for boot/login
      (writeShellScriptBin "restore-wallpaper" ''
        #!/usr/bin/env bash

        STATE_FILE="$HOME/.cache/wallpaper-state"

        # Check if state file exists
        if [[ ! -f "$STATE_FILE" ]]; then
          echo "No wallpaper state found"
          exit 0
        fi

        # Read the saved wallpaper path
        WALLPAPER=$(cat "$STATE_FILE")

        # Check if wallpaper file still exists (as file or symlink)
        if [[ ! -e "$WALLPAPER" ]]; then
          echo "Saved wallpaper no longer exists: $WALLPAPER"
          exit 1
        fi

        # Restore the wallpaper using our set-wallpaper script
        echo "Restoring wallpaper: $(basename "$WALLPAPER")"
        set-wallpaper "$WALLPAPER"
      '')

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
          -theme-str 'prompt { text-color: #${c theme.accent}; }')

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

      # Smart wallpaper setter that manages backends properly
      (writeShellScriptBin "set-wallpaper" ''
        #!/usr/bin/env bash

        WALLPAPER="$1"
        STATE_FILE="$HOME/.cache/wallpaper-state"
        CONFIG_FILE="$HOME/.config/wallpaper/config"

        if [[ ! -e "$WALLPAPER" ]]; then
          echo "Error: File not found: $WALLPAPER"
          exit 1
        fi

        # Read configuration from Nix-generated config file
        if [[ -f "$CONFIG_FILE" ]]; then
          source "$CONFIG_FILE"
        else
          # Fallback to defaults if config doesn't exist yet
          RESIZE_MODE="crop"
          VIDEO_RESIZE_MODE="crop"
          FILL_COLOR="000000"
          FILTER="Lanczos3"
          TRANSITION_TYPE="fade"
          TRANSITION_DURATION="3"
          TRANSITION_FPS="60"
          TRANSITION_STEP="90"
          TRANSITION_ANGLE="45"
          TRANSITION_POS="center"
          TRANSITION_BEZIER=".54,0,.34,.99"
          TRANSITION_WAVE="20,20"
        fi

        # Check for temporary testing override file
        # This file is created by wallpaper-testing command for temporary testing
        # It will be automatically cleared on system rebuild
        OVERRIDE_FILE="$HOME/.config/wallpaper/override"
        if [[ -f "$OVERRIDE_FILE" ]]; then
          source "$OVERRIDE_FILE"
        fi

        # Determine file type
        EXT="''${WALLPAPER##*.}"
        EXT="''${EXT,,}" # lowercase

        case "$EXT" in
          mp4|webm|mkv|avi|mov)
            # Video file - use mpvpaper
            echo "Setting video wallpaper with mpvpaper..."

            # Kill swww if running
            if pgrep -x swww-daemon > /dev/null; then
              swww kill
              sleep 0.5  # Brief pause to ensure clean shutdown
            fi

            # Kill any existing mpvpaper instances
            pkill -f mpvpaper

            # Start new mpvpaper with proper scaling based on video mode
            if [[ "$VIDEO_RESIZE_MODE" == "fit" ]]; then
              mpvpaper -o "loop --video-unscaled=no --panscan=0.0" '*' "$WALLPAPER" &
            else
              # Default to crop for videos
              mpvpaper -o "loop --video-unscaled=no --panscan=1.0" '*' "$WALLPAPER" &
            fi
            ;;

          gif)
            # GIF file - use swww
            echo "Setting GIF wallpaper with swww..."

            # Kill mpvpaper if running
            pkill -f mpvpaper

            # Ensure swww daemon is running
            if ! pgrep -x swww-daemon > /dev/null; then
              swww-daemon &
              sleep 0.5  # Wait for daemon to start
            fi

            # Set the wallpaper with appropriate resize mode (no transition for GIFs)
            case "$RESIZE_MODE" in
              fit)
                swww img "$WALLPAPER" --transition-type none --resize fit --fill-color "$FILL_COLOR" --filter "$FILTER"
                ;;
              stretch)
                swww img "$WALLPAPER" --transition-type none --resize stretch --filter "$FILTER"
                ;;
              no)
                swww img "$WALLPAPER" --transition-type none --no-resize --fill-color "$FILL_COLOR" --filter "$FILTER"
                ;;
              *)
                # Default to crop
                swww img "$WALLPAPER" --transition-type none --resize crop --filter "$FILTER"
                ;;
            esac
            ;;

          jpg|jpeg|png|webp|bmp)
            # Static image - use swww
            echo "Setting static wallpaper with swww..."

            # Kill mpvpaper if running
            pkill -f mpvpaper

            # Ensure swww daemon is running
            if ! pgrep -x swww-daemon > /dev/null; then
              swww-daemon &
              sleep 0.5  # Wait for daemon to start
            fi

            # Build swww command with all options
            SWWW_CMD="swww img \"$WALLPAPER\""
            SWWW_CMD="$SWWW_CMD --transition-type \"$TRANSITION_TYPE\""
            SWWW_CMD="$SWWW_CMD --transition-duration \"$TRANSITION_DURATION\""
            SWWW_CMD="$SWWW_CMD --transition-fps \"$TRANSITION_FPS\""
            SWWW_CMD="$SWWW_CMD --transition-step \"$TRANSITION_STEP\""
            SWWW_CMD="$SWWW_CMD --filter \"$FILTER\""

            # Add transition-specific options
            case "$TRANSITION_TYPE" in
              wipe|wave)
                SWWW_CMD="$SWWW_CMD --transition-angle \"$TRANSITION_ANGLE\""
                [[ "$TRANSITION_TYPE" == "wave" ]] && SWWW_CMD="$SWWW_CMD --transition-wave \"$TRANSITION_WAVE\""
                ;;
              grow|outer|center|any)
                SWWW_CMD="$SWWW_CMD --transition-pos \"$TRANSITION_POS\""
                ;;
              fade)
                SWWW_CMD="$SWWW_CMD --transition-bezier \"$TRANSITION_BEZIER\""
                ;;
            esac

            # Add resize mode
            case "$RESIZE_MODE" in
              fit)
                SWWW_CMD="$SWWW_CMD --resize fit --fill-color \"$FILL_COLOR\""
                ;;
              stretch)
                SWWW_CMD="$SWWW_CMD --resize stretch"
                ;;
              no)
                SWWW_CMD="$SWWW_CMD --no-resize --fill-color \"$FILL_COLOR\""
                ;;
              *)
                SWWW_CMD="$SWWW_CMD --resize crop"
                ;;
            esac

            # Execute the command
            eval "$SWWW_CMD"
            ;;

          *)
            echo "Unsupported file type: $EXT"
            exit 1
            ;;
        esac

        # Save wallpaper path to state file for restoration on boot
        mkdir -p "$(dirname "$STATE_FILE")"
        echo "$WALLPAPER" > "$STATE_FILE"

        echo "Wallpaper set: $(basename "$WALLPAPER")"
      '')

      # Rofi wallpaper picker with image previews
      (writeShellScriptBin "rofi-wallpaper" ''
        #!/usr/bin/env bash

        WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
        THUMB_DIR="$HOME/.cache/wallpaper-thumbs"

        # Create thumbnail cache directory
        mkdir -p "$THUMB_DIR"

        # Function to get or create video thumbnail
        get_video_thumb() {
          local video="$1"
          local thumb="$THUMB_DIR/$(basename "$video").jpg"

          # Generate thumbnail if it doesn't exist or is older than video
          if [[ ! -f "$thumb" ]] || [[ "$video" -nt "$thumb" ]]; then
            ${pkgs.ffmpeg}/bin/ffmpeg -i "$video" -ss 00:00:01 -vframes 1 "$thumb" -y &>/dev/null
          fi

          echo "$thumb"
        }

        # Create combined list with images first, then videos
        ALL_WALLPAPERS=""

        # First add all images and GIFs with preview icons
        while IFS= read -r file; do
          [[ -e "$file" ]] || continue  # Use -e to check if file/symlink exists
          name=$(basename "$file")
          # For images and GIFs, use the file itself as icon
          ALL_WALLPAPERS="$ALL_WALLPAPERS$name\x00icon\x1f$file\n"
        done < <(find "$WALLPAPER_DIR" -maxdepth 1 \( -type f -o -type l \) \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.jxl" \) | sort)

        # Then add videos with thumbnails
        while IFS= read -r file; do
          [[ -e "$file" ]] || continue  # Use -e to check if file/symlink exists
          name=$(basename "$file")
          # Generate/get thumbnail for video
          thumb=$(get_video_thumb "$file")
          # For videos, use thumbnail as icon and add 🎬 prefix
          ALL_WALLPAPERS="$ALL_WALLPAPERS🎬 $name\x00icon\x1f$thumb\n"
        done < <(find "$WALLPAPER_DIR" -maxdepth 1 \( -type f -o -type l \) \( -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" \) | sort)

        if [ -z "$ALL_WALLPAPERS" ]; then
          notify-send "No wallpapers found" "Add wallpapers to $WALLPAPER_DIR"
          exit 1
        fi

        # Show unified picker with 3x3 grid that fills the window better
        SELECTED=$(echo -en "$ALL_WALLPAPERS" | ${rofi-wayland}/bin/rofi -dmenu -p "Wallpapers" \
          -theme-str 'window {width: 750px; height: 750px;}' \
          -theme-str 'inputbar {padding: 10px;}' \
          -theme-str 'listview {columns: 3; lines: 3; spacing: 10px; flow: horizontal; padding: 10px;}' \
          -theme-str 'element {orientation: vertical; padding: 5px; spacing: 3px;}' \
          -theme-str 'element-icon {size: 180px;}' \
          -theme-str 'element-text {horizontal-align: 0.5; font: "CaskaydiaMono Nerd Font 9";}' \
          -show-icons \
          -markup-rows)

        [ -z "$SELECTED" ] && exit 0

        # Remove the 🎬 prefix if present for videos
        SELECTED="''${SELECTED#🎬 }"

        # Set the wallpaper using our smart setter
        set-wallpaper "$WALLPAPER_DIR/$SELECTED"

        notify-send "Wallpaper Changed" "$SELECTED" -t 2000
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

                # Get available networks (nmcli uses cached results by default, very fast)
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
                  nmcli dev wifi rescan 2>/dev/null
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

  # Configuration for rofi-rbw
  home.file.".config/rofi-rbw.rc".text = ''
    action = copy
    selector = rofi
    clipboarder = wl-copy
    typer = wtype
    clear-after = 60
  '';

  # Add keybinding for password manager in Hyprland
  wayland.windowManager.hyprland.settings.bind = [
    "$mod, I, exec, rofi-rbw" # Super+I for password manager
  ];
}
