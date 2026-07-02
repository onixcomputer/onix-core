# Idle management with screensaver → dim → DPMS off → optional suspend chain.
#
# Uses swayidle (works with any Wayland compositor supporting
# ext-idle-notify-v1, including niri). Shows a fullscreen terminal
# screensaver before dimming/powering down monitors. Noctalia locking is
# intentionally disabled.
#
# Timeline (using timeouts from shared/base/timeouts.nix):
#   dim - screensaverGraceSeconds : screensaver launches (pipes-rs in fullscreen terminal)
#   dim                           : screen dims via brightnessctl
#   lock                          : DPMS off (screen power down; historical timeout name)
#   suspend                       : system suspends when onix.idle.suspend.enable is true
{
  pkgs,
  lib,
  config,
  ...
}:
let
  screensaverGraceSeconds = 30;
  restartDelaySeconds = 5;
  screensaverPipeCount = 5;
  screensaverPipeRate = "0.002";
  dimBrightnessPercent = 10;

  screensaverTimeout = config.timeouts.dim - screensaverGraceSeconds;
  dimTimeout = config.timeouts.dim;
  lockTimeout = config.timeouts.lock;
  dpmsTimeout = lockTimeout;
  suspendTimeout = config.timeouts.suspend;
  idleSuspendEnabled = config.onix.idle.suspend.enable;

  # Launch screensaver in a fullscreen terminal window.
  # The window-rule in niri.nix matches app-id "screensaver" and
  # opens it fullscreen + floating.
  # Uses kitty with inline config overrides — wezterm removed --config
  # CLI flag. Pure black (#000000) background for OLED power savings.
  screensaver-start = pkgs.writeShellApplication {
    name = "screensaver-start";
    runtimeInputs = [
      pkgs.procps
      pkgs.pipes-rs
    ];
    text = ''
      # Don't stack screensavers
      pgrep -f "pipes-rs" >/dev/null && exit 0
      ${pkgs.kitty}/bin/kitty \
        --class screensaver \
        -o background=#000000 \
        -o window_padding_width=0 \
        -o hide_window_decorations=yes \
        -e pipes-rs -p ${toString screensaverPipeCount} -r ${screensaverPipeRate} &
    '';
  };

  screensaver-stop = pkgs.writeShellApplication {
    name = "screensaver-stop";
    runtimeInputs = [ pkgs.procps ];
    text = ''
      pkill -f "pipes-rs" 2>/dev/null || true
    '';
  };
in
{
  # r[onix.aspen3.power.idle]
  options.onix.idle.suspend.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether the Noctalia swayidle service should suspend the system after the
      configured idle suspend timeout. Disable this on machines that must stay
      reachable for remote builds, model downloads, or inference services while
      still allowing screen dimming and DPMS power-off.
    '';
  };

  config = {
    home.packages = [
      pkgs.swayidle
      pkgs.pipes-rs
    ];

    # swayidle as a systemd user service
    systemd.user.services.swayidle = {
      Unit = {
        Description = "Idle manager (screensaver, lock, DPMS)";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };

      Service = {
        Type = "simple";
        # -w = wait for command to finish before continuing idle timer
        ExecStart = builtins.concatStringsSep " " (
          [
            "${pkgs.swayidle}/bin/swayidle -w"

            # Screensaver — visual grace period before lock
            "timeout ${toString screensaverTimeout} '${lib.getExe screensaver-start}'"
            "resume '${lib.getExe screensaver-stop}'"

            # Dim screen
            "timeout ${toString dimTimeout} '${pkgs.brightnessctl}/bin/brightnessctl -s set ${toString dimBrightnessPercent}%'"
            "resume '${pkgs.brightnessctl}/bin/brightnessctl -r'"

            # Keep screensaver stopped once the long idle timeout is reached
            "timeout ${toString lockTimeout} '${lib.getExe screensaver-stop}'"

            # DPMS off
            "timeout ${toString dpmsTimeout} 'niri msg action power-off-monitors'"
          ]
          ++ lib.optionals idleSuspendEnabled [
            # Suspend
            "timeout ${toString suspendTimeout} 'systemctl suspend'"
          ]
        );
        Restart = "on-failure";
        RestartSec = restartDelaySeconds;
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
