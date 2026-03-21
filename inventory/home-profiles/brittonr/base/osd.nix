# On-screen display settings — thin stub over osd.ncl.
#
# Data and contracts live in osd.ncl.
{
  inputs,
  lib,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./osd.ncl;
in
{
  options.osd = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = data;
    description = "On-screen display (volume/brightness) settings";
  };
}
