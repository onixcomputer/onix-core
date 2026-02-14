{ lib, ... }:
{
  options.mediaPaths = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      musicDirectory = "/srv/music";
      playlistDirectory = "/srv/music/playlists";
      stateDirectory = "/var/lib/mpd";
      fifoPath = "/tmp/mpd.fifo";
    };
    description = "Media directory paths for MPD and related services";
  };
}
