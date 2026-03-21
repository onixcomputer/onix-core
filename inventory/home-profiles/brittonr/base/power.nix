# Power management settings — thin stub over power.ncl.
#
# Data and contracts live in power.ncl.
{
  inputs,
  lib,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./power.ncl;
in
{
  options.power = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = data;
    description = "Power management thresholds (battery and temperature levels)";
  };
}
