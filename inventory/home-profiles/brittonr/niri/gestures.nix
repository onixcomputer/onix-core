{ pkgs, ... }:
let
  inherit (pkgs) writeShellScriptBin;

  # Handler script that executes niri action + shows notification
  gestureHandler = writeShellScriptBin "gesture-handler" ''
    ACTION="$1"
    LABEL="$2"

    # Execute the niri action
    ${pkgs.niri}/bin/niri msg action "$ACTION"

    # Visual feedback via dunst notification (brief, low priority)
    ${pkgs.libnotify}/bin/notify-send -t 400 -u low \
      -h string:x-dunst-stack-tag:gesture \
      "Gesture" "$LABEL"
  '';

  # lisgd wrapper configured for GPD Pocket 4
  lisgdNiri = writeShellScriptBin "lisgd-niri" ''
    # Wait for Wayland session to be ready
    while [ -z "$WAYLAND_DISPLAY" ]; do sleep 0.5; done

    # Find the touchscreen device
    # GPD Pocket 4 uses i2c-hid touchscreen
    TOUCHSCREEN=$(${pkgs.libinput}/bin/libinput list-devices 2>/dev/null | \
      grep -B5 -i "touch" | grep "Kernel:" | head -1 | awk '{print $2}')

    if [ -z "$TOUCHSCREEN" ]; then
      echo "No touchscreen device found"
      exit 1
    fi

    echo "Starting lisgd on $TOUCHSCREEN"

    # lisgd gesture configuration
    # Format: -g "nfingers,gesture,edge,distance,actmode,command"
    #   nfingers: 1-N
    #   gesture: LR, RL, DU, UD (and diagonals)
    #   edge: L, R, T, B, *, N (left, right, top, bottom, any, none)
    #   distance: S, M, L, * (short, medium, long, any)
    #   actmode: R, P (released, pressed)

    exec ${pkgs.lisgd}/bin/lisgd \
      -d "$TOUCHSCREEN" \
      -o 0 \
      -t 150 \
      -g "1,DU,B,M,R,${gestureHandler}/bin/gesture-handler toggle-overview 'Overview'" \
      -g "2,LR,*,M,R,${gestureHandler}/bin/gesture-handler focus-workspace-up '← Prev WS'" \
      -g "2,RL,*,M,R,${gestureHandler}/bin/gesture-handler focus-workspace-down '→ Next WS'" \
      -g "2,DU,*,M,R,${gestureHandler}/bin/gesture-handler focus-column-left '↑ Prev Win'" \
      -g "2,UD,*,M,R,${gestureHandler}/bin/gesture-handler focus-column-right '↓ Next Win'" \
      -g "3,DU,*,*,R,${gestureHandler}/bin/gesture-handler toggle-overview 'Overview'"
  '';
in
{
  home.packages = [
    pkgs.lisgd
    gestureHandler
    lisgdNiri
  ];

  # Systemd user service for lisgd
  systemd.user.services.lisgd-niri = {
    Unit = {
      Description = "Touchscreen gesture daemon for Niri";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${lisgdNiri}/bin/lisgd-niri";
      Restart = "on-failure";
      RestartSec = "5s";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
