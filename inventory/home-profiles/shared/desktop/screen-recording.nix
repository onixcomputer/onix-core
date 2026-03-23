{ pkgs, ... }:
let
  record-screen = pkgs.writeShellApplication {
    name = "record-screen";
    runtimeInputs = [
      pkgs.wf-recorder
      pkgs.libnotify
      pkgs.coreutils
    ];
    text = ''
      DIR="$HOME/Videos/Recordings"
      mkdir -p "$DIR"
      FILE="$DIR/recording_$(date +%Y-%m-%d_%H-%M-%S).mp4"
      notify-send "Recording" "Screen recording started" -i media-record
      wf-recorder -a -f "$FILE"
      notify-send "Recording saved" "$FILE" -i media-record
    '';
  };

  record-region = pkgs.writeShellApplication {
    name = "record-region";
    runtimeInputs = [
      pkgs.wf-recorder
      pkgs.slurp
      pkgs.libnotify
      pkgs.coreutils
    ];
    text = ''
      DIR="$HOME/Videos/Recordings"
      mkdir -p "$DIR"
      FILE="$DIR/recording_$(date +%Y-%m-%d_%H-%M-%S).mp4"
      GEOM=$(slurp) || exit 0
      notify-send "Recording" "Region recording started" -i media-record
      wf-recorder -a -g "$GEOM" -f "$FILE"
      notify-send "Recording saved" "$FILE" -i media-record
    '';
  };

  record-stop = pkgs.writeShellApplication {
    name = "record-stop";
    runtimeInputs = [ pkgs.procps ];
    text = ''
      pkill -SIGINT wf-recorder 2>/dev/null || true
    '';
  };
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
