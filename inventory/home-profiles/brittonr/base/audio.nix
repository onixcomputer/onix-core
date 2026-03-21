# Audio settings — thin stub over audio.ncl.
#
# Data and contracts live in audio.ncl.
{
  inputs,
  lib,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./audio.ncl;
in
{
  options.audio = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = data;
    description = "Audio and volume control settings";
  };
}
