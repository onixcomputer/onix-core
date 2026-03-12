{
  inputs,
  pkgs,
  config,
  ...
}:
let
  inherit (pkgs) writeShellScriptBin;
  niriPackage = inputs.niri.packages.${pkgs.system}.niri;
  niri = "${niriPackage}/bin/niri";
  jq = "${pkgs.jq}/bin/jq";
  notifySend = "${pkgs.libnotify}/bin/notify-send";

  stickyFile = "$XDG_RUNTIME_DIR/niri-sticky-windows";

  # Daemon: listens to niri event-stream, moves sticky windows on workspace switch
  stickyDaemon = writeShellScriptBin "niri-sticky-daemon" ''
    #!/usr/bin/env bash
    set -euo pipefail

    STICKY_FILE="${stickyFile}"

    # Initialize empty sticky file
    : > "$STICKY_FILE"

    # Track the last workspace ID we moved sticky windows to,
    # so we skip duplicate events from the same switch.
    LAST_TARGET_WS=""

    ${niri} msg --json event-stream | while IFS= read -r event; do
      # Only care about WorkspaceActivated with focused=true
      ws_id=$(echo "$event" | ${jq} -r '.WorkspaceActivated // empty | select(.focused == true) | .id // empty' 2>/dev/null)
      [ -z "$ws_id" ] && continue

      # Skip if same workspace as last move (rapid duplicate events)
      [ "$ws_id" = "$LAST_TARGET_WS" ] && continue
      LAST_TARGET_WS="$ws_id"

      # Read sticky window IDs
      [ -f "$STICKY_FILE" ] || continue
      mapfile -t sticky_ids < "$STICKY_FILE"
      [ "''${#sticky_ids[@]}" -eq 0 ] && continue

      # Get the workspace index for move-window-to-workspace
      ws_idx=$(${niri} msg --json workspaces | ${jq} -r ".[] | select(.id == $ws_id) | .idx")
      [ -z "$ws_idx" ] && continue

      # Move each sticky window to the active workspace
      for wid in "''${sticky_ids[@]}"; do
        [ -z "$wid" ] && continue
        # Verify window still exists before moving
        if ${niri} msg --json windows | ${jq} -e ".[] | select(.id == ($wid | tonumber))" > /dev/null 2>&1; then
          ${niri} msg action move-window-to-workspace --window-id "$wid" --focus false "$ws_idx" 2>/dev/null || true
        else
          # Window gone -- remove from sticky file
          sed -i "/^$wid$/d" "$STICKY_FILE"
        fi
      done
    done
  '';

  # Toggle: pin/unpin the focused window
  toggleSticky = writeShellScriptBin "toggle-sticky-window" ''
    #!/usr/bin/env bash
    set -euo pipefail

    STICKY_FILE="${stickyFile}"

    # Get focused window info
    focused=$(${niri} msg --json focused-window 2>/dev/null) || {
      ${notifySend} -t ${toString config.timing.notification.quick} -u low "Sticky" "No focused window"
      exit 0
    }

    wid=$(echo "$focused" | ${jq} -r '.id')
    title=$(echo "$focused" | ${jq} -r '.title // "unknown"')
    is_floating=$(echo "$focused" | ${jq} -r '.is_floating')

    [ -z "$wid" ] || [ "$wid" = "null" ] && {
      ${notifySend} -t ${toString config.timing.notification.quick} -u low "Sticky" "No focused window"
      exit 0
    }

    # Ensure sticky file exists
    touch "$STICKY_FILE"

    # Check if already sticky
    if grep -qx "$wid" "$STICKY_FILE"; then
      # Unpin
      sed -i "/^$wid$/d" "$STICKY_FILE"
      ${notifySend} -t ${toString config.timing.notification.standard} -u low "Unpinned" "$title"
    else
      # Only allow floating windows to be pinned
      if [ "$is_floating" != "true" ]; then
        ${notifySend} -t ${toString config.timing.notification.standard} -u low "Sticky" "Window must be floating first"
        exit 0
      fi
      # Pin
      echo "$wid" >> "$STICKY_FILE"
      ${notifySend} -t ${toString config.timing.notification.standard} -u low "Pinned" "$title"
    fi
  '';
in
{
  home.packages = [
    stickyDaemon
    toggleSticky
  ];

  systemd.user.services.niri-sticky-daemon = {
    Unit = {
      Description = "Niri sticky/PiP window daemon";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${stickyDaemon}/bin/niri-sticky-daemon";
      Restart = "on-failure";
      RestartSec = config.serviceTiming.restartSec.fast;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
