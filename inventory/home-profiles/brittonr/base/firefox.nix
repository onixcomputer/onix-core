# Firefox tuning — thin stub over firefox.ncl.
#
# Data and contracts live in firefox.ncl.
{
  inputs,
  lib,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./firefox.ncl;
in
{
  options.firefox = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = data;
    description = "Firefox performance and tuning settings";
  };
}
