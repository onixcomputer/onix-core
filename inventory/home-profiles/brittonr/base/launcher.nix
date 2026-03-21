# Application launcher settings — thin stub over launcher.ncl.
#
# Data and contracts live in launcher.ncl.
{
  inputs,
  lib,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./launcher.ncl;
in
{
  options.launcher = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = data;
    description = "Application launcher settings";
  };
}
