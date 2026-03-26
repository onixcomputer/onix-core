{
  inputs,
  pkgs,
  lib,
  config,
  ...
}:
let
  niriPackage = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri;

  # Handler script that executes niri action + shows notification
  gestureHandler = pkgs.writeShellApplication {
    name = "gesture-handler";
    runtimeInputs = [
      niriPackage
      pkgs.libnotify
    ];
    text = ''
      ACTION="$1"
      LABEL="$2"

      # Execute the niri action
      niri msg action "$ACTION"

      # Visual feedback via notification (brief, low priority)
      notify-send -t ${toString config.timing.notification.gesture} -u low \
        "Gesture" "$LABEL"
    '';
  };

  # lisgd wrapper configured for GPD Pocket 4
  lisgdNiri = pkgs.writeShellApplication {
    name = "lisgd-niri";
    runtimeInputs = [
      pkgs.libinput
      pkgs.gawk
      pkgs.lisgd
    ];
    text = ''
      # Find actual touchscreen devices (not touchpads) by checking
      # for "touch" in the Capabilities line from libinput.
      # Check before waiting for Wayland — no point waiting on machines without a touchscreen.
      TOUCHSCREEN=$(libinput list-devices 2>/dev/null | \
        awk '
          /^Device:/ { dev="" }
          /^Kernel:/ { dev=$2 }
          /^Capabilities:.*\btouch\b/ { if (dev) { print dev; exit } }
        ') || true

      if [ -z "$TOUCHSCREEN" ]; then
        echo "No touchscreen device found, exiting"
        exit 0
      fi

      # Wait for Wayland session to be ready (bounded: 60 attempts ≈ 30s)
      attempts=0
      max_attempts=60
      while [ -z "''${WAYLAND_DISPLAY:-}" ]; do
        attempts=$((attempts + 1))
        if [ "$attempts" -ge "$max_attempts" ]; then
          echo "Timed out waiting for WAYLAND_DISPLAY after $max_attempts attempts"
          exit 1
        fi
        sleep ${config.timing.process.short}
      done

      echo "Starting lisgd on $TOUCHSCREEN"

      # lisgd gesture configuration
      # Format: -g "nfingers,gesture,edge,distance,actmode,command"
      #   nfingers: 1-N
      #   gesture: LR, RL, DU, UD (and diagonals)
      #   edge: L, R, T, B, *, N (left, right, top, bottom, any, none)
      #   distance: S, M, L, * (short, medium, long, any)
      #   actmode: R, P (released, pressed)

      exec lisgd \
        -d "$TOUCHSCREEN" \
        -o ${toString config.gestures.lisgd.outputIndex} \
        -t ${toString config.gestures.lisgd.timeout} \
        -g "1,DU,B,M,R,${lib.getExe gestureHandler} toggle-overview 'Overview'" \
        -g "2,LR,*,M,R,${lib.getExe gestureHandler} focus-workspace-up '← Prev WS'" \
        -g "2,RL,*,M,R,${lib.getExe gestureHandler} focus-workspace-down '→ Next WS'" \
        -g "2,DU,*,M,R,${lib.getExe gestureHandler} focus-column-left '↑ Prev Win'" \
        -g "2,UD,*,M,R,${lib.getExe gestureHandler} focus-column-right '↓ Next Win'" \
        -g "3,DU,*,*,R,${lib.getExe gestureHandler} toggle-overview 'Overview'"
    '';
  };
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
      # Stop restarting if lisgd crashes repeatedly (wrong device, perms, etc.)
      StartLimitBurst = 3;
      StartLimitIntervalSec = 30;
    };
    Service = {
      Type = "simple";
      ExecStart = lib.getExe lisgdNiri;
      Restart = "on-failure";
      RestartSec = config.serviceTiming.restartSec.fast;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
