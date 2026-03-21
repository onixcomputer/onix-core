# Gesture configuration — thin stub over gestures.ncl.
#
# Data and contracts live in gestures.ncl.
{
  inputs,
  lib,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./gestures.ncl;
in
{
  options.gestures = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = data;
    description = "Gesture configuration for touchpad and touchscreen";
  };
}
