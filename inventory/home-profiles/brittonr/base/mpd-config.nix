{ lib, ... }:
{
  options.mpdConfig = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      port = 6600;
      httpPort = 8000;
      bufferSize = "4096";
      maxConnections = "20";
      connectionTimeout = "60";
      format = "44100:16:2";
      replaygain = "album";
    };
    description = "MPD service parameters for music playback and streaming";
  };
}
