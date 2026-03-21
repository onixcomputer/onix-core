# LibreWolf overrides — thin stub over librewolf.ncl.
#
# Data and contracts live in librewolf.ncl.
{
  inputs,
  lib,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./librewolf.ncl;
in
{
  options.librewolf = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = data;
    description = "LibreWolf about:config overrides";
  };
}
