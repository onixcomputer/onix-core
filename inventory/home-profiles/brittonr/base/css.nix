# CSS sizing and timing values — thin stub over css.ncl.
#
# Data and contracts live in css.ncl.
{
  inputs,
  lib,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./css.ncl;
in
{
  options.css = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = data;
    description = "Shared CSS sizing and timing values for waybar and other GTK widgets";
  };
}
