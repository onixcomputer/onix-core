# Input device settings — thin stub over input.ncl.
#
# Data and contracts live in input.ncl.
{
  inputs,
  lib,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./input.ncl;
in
{
  options.input = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = data;
    description = "Input device settings for keyboards, touchpads, and mice";
  };
}
