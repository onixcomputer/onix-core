{ pkgs, ... }:
let
  record-screen = pkgs.writeShellScriptBin "record-screen" ''
    DIR="$HOME/Videos/Recordings"
    mkdir -p "$DIR"
    FILE="$DIR/recording_$(date +%Y-%m-%d_%H-%M-%S).mp4"
    ${pkgs.libnotify}/bin/notify-send "Recording" "Screen recording started" -i media-record
    ${pkgs.wf-recorder}/bin/wf-recorder -a -f "$FILE"
    ${pkgs.libnotify}/bin/notify-send "Recording saved" "$FILE" -i media-record
  '';

  record-region = pkgs.writeShellScriptBin "record-region" ''
    DIR="$HOME/Videos/Recordings"
    mkdir -p "$DIR"
    FILE="$DIR/recording_$(date +%Y-%m-%d_%H-%M-%S).mp4"
    GEOM=$(${pkgs.slurp}/bin/slurp) || exit 0
    ${pkgs.libnotify}/bin/notify-send "Recording" "Region recording started" -i media-record
    ${pkgs.wf-recorder}/bin/wf-recorder -a -g "$GEOM" -f "$FILE"
    ${pkgs.libnotify}/bin/notify-send "Recording saved" "$FILE" -i media-record
  '';

  record-stop = pkgs.writeShellScriptBin "record-stop" ''
    ${pkgs.procps}/bin/pkill -SIGINT wf-recorder 2>/dev/null || true
  '';
in
{
  home.packages = [
    pkgs.wf-recorder
    pkgs.slurp
    pkgs.libnotify
    pkgs.procps
    record-screen
    record-region
    record-stop
  ];

  home.file."Videos/Recordings/.keep".text = "";
}
