# Screenshot annotation settings — thin stub over screenshot.ncl.
#
# Data and contracts live in screenshot.ncl.
{
  inputs,
  lib,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./screenshot.ncl;
in
{
  options.screenshot = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = data;
    description = "Screenshot annotation tool (satty) settings";
  };
}
