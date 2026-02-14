{ pkgs, config, ... }:
let
  inherit (pkgs) writeShellScriptBin;
in
{
  home.packages = [
    # Smart wallpaper setter that handles images, GIFs, and videos
    (writeShellScriptBin "set-wallpaper" ''
      #!/usr/bin/env bash

      WALLPAPER="$1"
      STATE_FILE="$HOME/.cache/wallpaper-state"

      if [[ ! -e "$WALLPAPER" ]]; then
        echo "Error: File not found: $WALLPAPER"
        exit 1
      fi

      # Determine file type
      EXT="''${WALLPAPER##*.}"
      EXT="''${EXT,,}" # lowercase

      case "$EXT" in
        mp4|webm|mkv|avi|mov)
          # Video file - use mpvpaper
          echo "Setting video wallpaper with mpvpaper..."

          # Kill swww if running
          if ${pkgs.procps}/bin/pgrep -x swww-daemon > /dev/null; then
            ${pkgs.swww}/bin/swww kill
            sleep ${config.timing.process.short}
          fi

          # Kill any existing mpvpaper instances
          ${pkgs.procps}/bin/pkill -x mpvpaper 2>/dev/null || true
          sleep ${config.timing.process.veryShort}

          # Get all outputs from niri
          OUTPUTS=$(niri msg outputs | ${pkgs.jq}/bin/jq -r '.[].name')

          # Start mpvpaper for each output
          while IFS= read -r output; do
            ${pkgs.mpvpaper}/bin/mpvpaper -o "panscan=1.0" "$output" "$WALLPAPER" &
          done <<< "$OUTPUTS"

          echo "Video wallpaper set: $(basename "$WALLPAPER")"
          ;;

        gif)
          # GIF file - use swww (better GIF support)
          echo "Setting GIF wallpaper with swww..."

          # Kill mpvpaper if running
          ${pkgs.procps}/bin/pkill -x mpvpaper 2>/dev/null || true

          # Start swww daemon if not running
          if ! ${pkgs.procps}/bin/pgrep -x swww-daemon > /dev/null; then
            ${pkgs.swww}/bin/swww-daemon &
            sleep ${config.timing.process.daemonStart}
          fi

          # Set the GIF on all outputs
          ${pkgs.swww}/bin/swww img "$WALLPAPER" \
            --resize crop \
            --fill-color ${config.wallpaper.fillColor} \
            --filter Lanczos3 \
            --transition-type ${config.wallpaper.gif.transitionType} \
            --transition-duration ${toString config.wallpaper.gif.transitionDuration} \
            --transition-fps ${toString config.wallpaper.gif.transitionFps}

          echo "GIF wallpaper set: $(basename "$WALLPAPER")"
          ;;

        jpg|jpeg|png|webp|jxl)
          # Static image - use swww
          echo "Setting static wallpaper with swww..."

          # Kill mpvpaper if running
          ${pkgs.procps}/bin/pkill -x mpvpaper 2>/dev/null || true

          # Start swww daemon if not running
          if ! ${pkgs.procps}/bin/pgrep -x swww-daemon > /dev/null; then
            ${pkgs.swww}/bin/swww-daemon &
            sleep ${config.timing.process.daemonStart}
          fi

          # Set the wallpaper on all outputs
          ${pkgs.swww}/bin/swww img "$WALLPAPER" \
            --resize crop \
            --fill-color ${config.wallpaper.fillColor} \
            --filter Lanczos3 \
            --transition-type ${config.wallpaper.static.transitionType} \
            --transition-duration ${toString config.wallpaper.static.transitionDuration} \
            --transition-fps ${toString config.wallpaper.static.transitionFps} \
            --transition-step ${toString config.wallpaper.static.transitionStep} \
            --transition-pos ${config.wallpaper.static.transitionPos} \
            --transition-bezier ${config.wallpaper.static.transitionBezier}

          echo "Static wallpaper set: $(basename "$WALLPAPER")"
          ;;

        *)
          echo "Error: Unsupported file type: $EXT"
          exit 1
          ;;
      esac

      # Save wallpaper path for restoration
      echo "$WALLPAPER" > "$STATE_FILE"
    '')

    # Wallpaper restoration script for boot/login
    (writeShellScriptBin "restore-wallpaper" ''
      #!/usr/bin/env bash

      STATE_FILE="$HOME/.cache/wallpaper-state"
      DEFAULT_WALLPAPER="$HOME/git/wallpapers/1-matte-black.jpg"

      # Check if state file exists
      if [[ ! -f "$STATE_FILE" ]]; then
        echo "No wallpaper state found, using default"
        WALLPAPER="$DEFAULT_WALLPAPER"
      else
        # Read the saved wallpaper path
        WALLPAPER=$(cat "$STATE_FILE")

        # Check if wallpaper file still exists (as file or symlink)
        if [[ ! -e "$WALLPAPER" ]]; then
          echo "Saved wallpaper no longer exists: $WALLPAPER, using default"
          WALLPAPER="$DEFAULT_WALLPAPER"
        fi
      fi

      # Restore the wallpaper using our set-wallpaper script
      echo "Restoring wallpaper: $(basename "$WALLPAPER")"
      set-wallpaper "$WALLPAPER"
    '')

    # Fuzzel wallpaper picker (simpler version without image previews)
    (writeShellScriptBin "fuzzel-wallpaper" ''
      #!/usr/bin/env bash

      WALLPAPER_DIR="$HOME/git/wallpapers"

      # Create combined list with images first, then videos
      ALL_WALLPAPERS=""

      # Add all images and GIFs
      while IFS= read -r file; do
        [[ -e "$file" ]] || continue
        name=$(basename "$file")
        ALL_WALLPAPERS="$ALL_WALLPAPERS$name\n"
      done < <(find "$WALLPAPER_DIR" -maxdepth 1 \( -type f -o -type l \) \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" -o -iname "*.jxl" \) | sort)

      # Add videos with 🎬 prefix
      while IFS= read -r file; do
        [[ -e "$file" ]] || continue
        name=$(basename "$file")
        ALL_WALLPAPERS="$ALL_WALLPAPERS🎬 $name\n"
      done < <(find "$WALLPAPER_DIR" -maxdepth 1 \( -type f -o -type l \) \( -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" \) | sort)

      if [ -z "$ALL_WALLPAPERS" ]; then
        ${pkgs.libnotify}/bin/notify-send "No wallpapers found" "Add wallpapers to $WALLPAPER_DIR"
        exit 1
      fi

      # Show picker
      SELECTED=$(echo -en "$ALL_WALLPAPERS" | ${pkgs.fuzzel}/bin/fuzzel --dmenu --prompt "Wallpapers: ")

      [ -z "$SELECTED" ] && exit 0

      # Remove the 🎬 prefix if present for videos
      SELECTED="''${SELECTED#🎬 }"

      # Set the wallpaper using our smart setter
      set-wallpaper "$WALLPAPER_DIR/$SELECTED"

      ${pkgs.libnotify}/bin/notify-send "Wallpaper Changed" "$SELECTED" -t ${toString config.timing.notification.standard}
    '')

    # Fuzzel network menu
    (writeShellScriptBin "fuzzel-network-menu" ''
            # Detect active connection type
            active_type=$(${pkgs.networkmanager}/bin/nmcli -t -f TYPE,STATE con show --active | grep activated | cut -d: -f1)

            if [ "$active_type" = "802-3-ethernet" ]; then
              # Ethernet is connected - show ethernet options
              menu="󰢾  Network Settings
      󰖩  Switch to WiFi

      󰈁  Ethernet Connected"

              chosen=$(echo -e "$menu" | ${pkgs.fuzzel}/bin/fuzzel --dmenu --prompt "Network: ")

              case "$chosen" in
                *"Network Settings")
                  ${pkgs.networkmanagerapplet}/bin/nm-connection-editor &
                  ;;
                *"Switch to WiFi")
                  fuzzel-wifi
                  ;;
              esac
            else
              # WiFi or disconnected - show WiFi menu
              fuzzel-wifi
            fi
    '')

    # Fuzzel NixOS generation switcher
    (writeShellScriptBin "fuzzel-generations" ''
      #!/usr/bin/env bash

      # Get list of system generations
      generations=$(sudo ${pkgs.nix}/bin/nix-env --list-generations --profile /nix/var/nix/profiles/system)

      # Get current generation number
      current=$(sudo ${pkgs.nix}/bin/nix-env --profile /nix/var/nix/profiles/system --list-generations | grep current | awk '{print $1}')

      # Format for fuzzel
      formatted_list=""
      while IFS= read -r line; do
        gen_num=$(echo "$line" | awk '{print $1}')
        gen_date=$(echo "$line" | awk '{print $2, $3}')
        is_current=$(echo "$line" | grep -q "current" && echo " (current)" || echo "")

        # Add indicator for current generation
        if [ "$gen_num" = "$current" ]; then
          icon="  "
        else
          icon="  "
        fi

        formatted_list="$formatted_list$icon Gen $gen_num - $gen_date$is_current\n"
      done <<< "$generations"

      # Add menu options at top
      menu="  Rebuild System
        Collect Garbage
        List Generations

      $formatted_list"

      chosen=$(echo -en "$menu" | ${pkgs.fuzzel}/bin/fuzzel --dmenu --prompt "NixOS: " --width 60)

      [ -z "$chosen" ] && exit 0

      case "$chosen" in
        *"Rebuild System")
          ${pkgs.libnotify}/bin/notify-send "NixOS" "Rebuilding system..." -t ${toString config.timing.notification.standard}
          ${config.apps.terminal.command} --hold sudo nixos-rebuild switch
          ;;
        *"Collect Garbage")
          ${config.apps.terminal.command} --hold sudo ${pkgs.nix}/bin/nix-collect-garbage -d
          ${pkgs.libnotify}/bin/notify-send "NixOS" "Garbage collection complete"
          ;;
        *"List Generations")
          ${config.apps.terminal.command} --hold sudo ${pkgs.nix}/bin/nix-env --list-generations --profile /nix/var/nix/profiles/system
          ;;
        *)
          # Extract generation number
          gen_num=$(echo "$chosen" | sed 's/^[[:space:]]*[  ]*//' | awk '{print $2}')

          # Check if trying to switch to current
          if [ "$gen_num" = "$current" ]; then
            ${pkgs.libnotify}/bin/notify-send "NixOS" "Already on generation $gen_num"
            exit 0
          fi

          # Confirm switch
          confirm=$(echo -e "Yes\nNo" | ${pkgs.fuzzel}/bin/fuzzel --dmenu --prompt "Switch to generation $gen_num? ")

          if [ "$confirm" = "Yes" ]; then
            ${pkgs.libnotify}/bin/notify-send "NixOS" "Switching to generation $gen_num..." -t ${toString config.timing.notification.standard}
            sudo /nix/var/nix/profiles/system-$gen_num-link/bin/switch-to-configuration switch

            if [ $? -eq 0 ]; then
              ${pkgs.libnotify}/bin/notify-send "NixOS" "Switched to generation $gen_num"
            else
              ${pkgs.libnotify}/bin/notify-send "NixOS" "Failed to switch to generation $gen_num" -u critical
            fi
          fi
          ;;
      esac
    '')

    # Theme mode toggle (light/dark)
    (writeShellScriptBin "toggle-theme-mode" ''
      #!/usr/bin/env bash

      # Get current color scheme
      current_scheme=$(${pkgs.dconf}/bin/dconf read /org/gnome/desktop/interface/color-scheme)

      # Toggle between light and dark
      if [[ "$current_scheme" == "'prefer-dark'" ]]; then
        ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-light'"
        ${pkgs.libnotify}/bin/notify-send "Theme Mode" "Switched to Light Mode ☀" -t ${toString config.timing.notification.standard}
      else
        ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
        ${pkgs.libnotify}/bin/notify-send "Theme Mode" "Switched to Dark Mode 🌙" -t ${toString config.timing.notification.standard}
      fi
    '')

    # Fuzzel theme mode selector (manual control)
    (writeShellScriptBin "fuzzel-theme-mode" ''
          #!/usr/bin/env bash

          # Get current color scheme
          current_scheme=$(${pkgs.dconf}/bin/dconf read /org/gnome/desktop/interface/color-scheme)

          # Format menu with current selection indicator
          if [[ "$current_scheme" == "'prefer-dark'" ]]; then
            menu="  🌙 Dark Mode (current)
      ☀ Light Mode
      🔄 Auto (follow system)"
          else
            menu="  ☀ Light Mode (current)
      🌙 Dark Mode
      🔄 Auto (follow system)"
          fi

          chosen=$(echo -e "$menu" | ${pkgs.fuzzel}/bin/fuzzel --dmenu --prompt "Theme Mode: ")

          [ -z "$chosen" ] && exit 0

          case "$chosen" in
            *"Dark Mode"*)
              ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
              ${pkgs.libnotify}/bin/notify-send "Theme Mode" "Switched to Dark Mode 🌙" -t ${toString config.timing.notification.standard}
              ;;
            *"Light Mode"*)
              ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-light'"
              ${pkgs.libnotify}/bin/notify-send "Theme Mode" "Switched to Light Mode ☀" -t ${toString config.timing.notification.standard}
              ;;
            *"Auto"*)
              ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'default'"
              ${pkgs.libnotify}/bin/notify-send "Theme Mode" "Set to Auto (follow system) 🔄" -t ${toString config.timing.notification.standard}
              ;;
          esac
    '')

    # Fuzzel darkman control menu
    (writeShellScriptBin "fuzzel-darkman" ''
          #!/usr/bin/env bash

          # Check if darkman is running
          if ! ${pkgs.systemd}/bin/systemctl --user is-active --quiet darkman.service; then
            ${pkgs.libnotify}/bin/notify-send "Darkman" "Darkman service is not running" -u critical
            exit 1
          fi

          # Get darkman status
          darkman_mode=$(${pkgs.darkman}/bin/darkman get 2>/dev/null || echo "unknown")

          # Format menu with current status
          menu="  Current Mode: $darkman_mode

      🌙 Switch to Dark Now
      ☀ Switch to Light Now
      🔄 Let Darkman Auto-Switch
      📍 Show Location & Times
      ℹ️  Darkman Status"

          chosen=$(echo -e "$menu" | ${pkgs.fuzzel}/bin/fuzzel --dmenu --prompt "Darkman: " --width 60)

          [ -z "$chosen" ] && exit 0

          case "$chosen" in
            *"Switch to Dark Now"*)
              ${pkgs.darkman}/bin/darkman set dark
              ${pkgs.libnotify}/bin/notify-send "Darkman" "Manually switched to Dark Mode 🌙" -t ${toString config.timing.notification.standard}
              ;;
            *"Switch to Light Now"*)
              ${pkgs.darkman}/bin/darkman set light
              ${pkgs.libnotify}/bin/notify-send "Darkman" "Manually switched to Light Mode ☀" -t ${toString config.timing.notification.standard}
              ;;
            *"Let Darkman Auto-Switch"*)
              # Toggle mode to trigger darkman to re-evaluate
              if [[ "$darkman_mode" == "dark" ]]; then
                ${pkgs.darkman}/bin/darkman set light
                sleep ${config.timing.process.short}
              fi
              ${pkgs.darkman}/bin/darkman toggle
              ${pkgs.libnotify}/bin/notify-send "Darkman" "Darkman will now auto-switch based on time 🔄" -t ${toString config.timing.notification.standard}
              ;;
            *"Show Location & Times"*)
              # Get location info from darkman
              location_info=$(${pkgs.systemd}/bin/systemctl --user show darkman.service --property=StatusText --value 2>/dev/null)
              if [ -z "$location_info" ]; then
                location_info="Location info not available.\nDarkman may still be starting up or geoclue is not configured."
              fi
              ${pkgs.libnotify}/bin/notify-send "Darkman Location" "$location_info" -t ${toString config.timing.notification.long}
              ;;
            *"Darkman Status"*)
              # Show full status
              status=$(${pkgs.systemd}/bin/systemctl --user status darkman.service --no-pager --lines=20)
              ${config.apps.terminal.command} --hold sh -c "echo 'Darkman Service Status:'; echo; ${pkgs.systemd}/bin/systemctl --user status darkman.service --no-pager --lines=30"
              ;;
          esac
    '')

    # Scratchpad toggle - per-workspace floating kitty terminal
    (writeShellScriptBin "toggle-scratchpad" ''
      #!/usr/bin/env bash

      # Get current workspace info
      CURRENT_WORKSPACE=$(niri msg workspaces | ${pkgs.jq}/bin/jq -r '.[] | select(.is_active == true) | .name')

      # Hidden workspace for scratchpads
      HIDDEN_WORKSPACE="hidden"

      # Scratchpad app-id for this workspace (using --class flag)
      SCRATCHPAD_CLASS="scratchpad-$CURRENT_WORKSPACE"

      # Check if this workspace's scratchpad exists by app-id
      SCRATCHPAD_INFO=$(niri msg windows | ${pkgs.jq}/bin/jq -r ".[] | select(.app_id == \"$SCRATCHPAD_CLASS\") | {id: .id, workspace: .workspace_name}")

      if [ -n "$SCRATCHPAD_INFO" ]; then
        # Scratchpad exists - check which workspace it's on
        SCRATCHPAD_WORKSPACE=$(echo "$SCRATCHPAD_INFO" | ${pkgs.jq}/bin/jq -r '.workspace')
        SCRATCHPAD_ID=$(echo "$SCRATCHPAD_INFO" | ${pkgs.jq}/bin/jq -r '.id')

        if [ "$SCRATCHPAD_WORKSPACE" = "$CURRENT_WORKSPACE" ]; then
          # Scratchpad is visible - hide it by moving to hidden workspace
          niri msg action focus-window --id "$SCRATCHPAD_ID"
          niri msg action move-column-to-workspace "$HIDDEN_WORKSPACE"
        else
          # Scratchpad is hidden - show it by moving to current workspace
          niri msg action focus-window --id "$SCRATCHPAD_ID"
          niri msg action move-column-to-workspace "$CURRENT_WORKSPACE"
          niri msg action focus-window --id "$SCRATCHPAD_ID"
        fi
      else
        # No scratchpad for this workspace - create a kitty terminal
        # Get current working directory from focused window for context
        PID=$(niri msg windows | ${pkgs.jq}/bin/jq -r '.[] | select(.is_focused == true) | .pid')
        DIR=""

        if [ -n "$PID" ] && [ "$PID" != "null" ]; then
          SHELL_PID=$(${pkgs.procps}/bin/pgrep -P "$PID" -x "fish|zsh|bash|sh" | head -1)

          if [ -n "$SHELL_PID" ]; then
            TARGET_PID="$SHELL_PID"
          else
            TARGET_PID="$PID"
          fi

          if [ -e "/proc/$TARGET_PID/cwd" ]; then
            DIR=$(readlink "/proc/$TARGET_PID/cwd" 2>/dev/null)
          fi
        fi

        # Default to home if we couldn't get CWD
        [ -z "$DIR" ] || [ ! -d "$DIR" ] && DIR="$HOME"

        # Spawn kitty scratchpad with custom app-id (using --name for Wayland)
        ${config.apps.terminal.command} --name="$SCRATCHPAD_CLASS" --directory="$DIR" &
      fi
    '')

    # Fuzzel WiFi picker
    (writeShellScriptBin "fuzzel-wifi" ''
            #!/usr/bin/env bash

            # Get list of available WiFi networks
            wifi_list=$(${pkgs.networkmanager}/bin/nmcli -f SSID,SIGNAL,SECURITY device wifi list | tail -n +2)

            # Get currently connected network
            connected=$(${pkgs.networkmanager}/bin/nmcli -t -f NAME connection show --active | head -n1)

            # Format for fuzzel with icons
            formatted_list=""
            while IFS= read -r line; do
              ssid=$(echo "$line" | awk '{print $1}')
              signal=$(echo "$line" | awk '{print $2}')
              security=$(echo "$line" | awk '{print $3}')

              # Add connection icon if connected
              if [ "$ssid" = "$connected" ]; then
                icon="󰤨 "
              else
                icon="  "
              fi

              # Add lock icon if secured
              if [ -n "$security" ] && [ "$security" != "--" ]; then
                lock=" 󰌾"
              else
                lock=""
              fi

              formatted_list="$formatted_list$icon$ssid ($signal%)$lock\n"
            done <<< "$wifi_list"

            # Add menu options at top
            menu="󰢾  Network Settings
      󰛵  Rescan Networks

      $formatted_list"

            chosen=$(echo -en "$menu" | ${pkgs.fuzzel}/bin/fuzzel --dmenu --prompt "WiFi: ")

            [ -z "$chosen" ] && exit 0

            case "$chosen" in
              *"Network Settings")
                ${pkgs.networkmanagerapplet}/bin/nm-connection-editor &
                ;;
              *"Rescan Networks")
                ${pkgs.libnotify}/bin/notify-send -t ${toString config.timing.notification.quick} "WiFi 󰤨" "Scanning networks..."
                ${pkgs.networkmanager}/bin/nmcli device wifi rescan
                sleep ${config.timing.process.wifiScan}
                fuzzel-wifi
                ;;
              *)
                # Extract SSID from selection (remove icons and signal info)
                ssid=$(echo "$chosen" | sed 's/^[[:space:]]*[󰤨 ]*//' | sed 's/ ([0-9]*%).*$//')

                # Check if network is already saved
                if ${pkgs.networkmanager}/bin/nmcli connection show | grep -q "^$ssid "; then
                  ${pkgs.networkmanager}/bin/nmcli connection up "$ssid"
                else
                  # New network - prompt for password if secured
                  if echo "$chosen" | grep -q "󰌾"; then
                    password=$(echo "" | ${pkgs.fuzzel}/bin/fuzzel --dmenu --prompt "Password for $ssid: " --password)
                    [ -z "$password" ] && exit 0
                    ${pkgs.networkmanager}/bin/nmcli device wifi connect "$ssid" password "$password"
                  else
                    ${pkgs.networkmanager}/bin/nmcli device wifi connect "$ssid"
                  fi
                fi

                # Show notification
                if [ $? -eq 0 ]; then
                  ${pkgs.libnotify}/bin/notify-send "WiFi Connected" "$ssid"
                else
                  ${pkgs.libnotify}/bin/notify-send "WiFi Failed" "Could not connect to $ssid"
                fi
                ;;
            esac
    '')
  ];
}
