# MPD config — thin stub over mpd-config.ncl.
#
# Data and contracts live in mpd-config.ncl.
{
  inputs,
  lib,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./mpd-config.ncl;
in
{
  options.mpdConfig = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = data;
    description = "MPD service parameters for music playback and streaming";
  };
}
