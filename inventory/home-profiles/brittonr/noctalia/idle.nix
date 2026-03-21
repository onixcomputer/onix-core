# Idle management with screensaver → lock → DPMS off chain.
#
# Uses swayidle (works with any Wayland compositor supporting
# ext-idle-notify-v1, including niri). Shows a fullscreen terminal
# screensaver as a grace period before locking.
#
# Timeline (using timeouts from shared/base/timeouts.nix):
#   dim - 30s : screensaver launches (pipes-rs in fullscreen terminal)
#   dim       : screen dims via brightnessctl
#   lock      : noctalia lock screen activates, screensaver killed
#   lock + 30s: DPMS off (screen power down)
#   suspend   : system suspends
{
  pkgs,
  config,
  ...
}:
let
  screensaverTimeout = config.timeouts.dim - 30;
  dimTimeout = config.timeouts.dim;
  lockTimeout = config.timeouts.lock;
  dpmsTimeout = lockTimeout + 30;
  suspendTimeout = config.timeouts.suspend;

  # Launch screensaver in a fullscreen terminal window.
  # The window-rule in niri.nix matches app-id "screensaver" and
  # opens it fullscreen + floating.
  screensaver-start = pkgs.writeShellScript "screensaver-start" ''
    # Don't stack screensavers
    ${pkgs.procps}/bin/pgrep -f "pipes-rs" >/dev/null && exit 0
    ${config.apps.terminal.command} start --class screensaver -- \
      ${pkgs.pipes-rs}/bin/pipes-rs -p 5 -r 0.002 &
  '';

  screensaver-stop = pkgs.writeShellScript "screensaver-stop" ''
    ${pkgs.procps}/bin/pkill -f "pipes-rs" 2>/dev/null || true
  '';
in
{
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
      ExecStart = builtins.concatStringsSep " " [
        "${pkgs.swayidle}/bin/swayidle -w"

        # Screensaver — visual grace period before lock
        "timeout ${toString screensaverTimeout} '${screensaver-start}'"
        "resume '${screensaver-stop}'"

        # Dim screen
        "timeout ${toString dimTimeout} '${pkgs.brightnessctl}/bin/brightnessctl -s set 10%'"
        "resume '${pkgs.brightnessctl}/bin/brightnessctl -r'"

        # Lock via noctalia
        "timeout ${toString lockTimeout} 'noctalia-shell ipc call lockScreen lock'"
        "resume '${screensaver-stop}'"

        # DPMS off
        "timeout ${toString dpmsTimeout} 'niri msg action power-off-monitors'"

        # Suspend
        "timeout ${toString suspendTimeout} 'systemctl suspend'"

        # Lock before sleep (lid close, manual suspend)
        "before-sleep 'noctalia-shell ipc call lockScreen lock'"
      ];
      Restart = "on-failure";
      RestartSec = 5;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
