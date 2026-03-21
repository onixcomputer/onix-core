# Lock screen settings — thin stub over lockscreen.ncl.
#
# Data and contracts live in lockscreen.ncl.
{
  inputs,
  lib,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./lockscreen.ncl;
in
{
  options.lockscreen = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = data;
    description = "Lock screen (hyprlock) styling settings";
  };
}
