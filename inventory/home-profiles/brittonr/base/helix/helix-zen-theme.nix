# Helix zen mode theme — thin stub over helix-zen-theme.ncl.
#
# Each zen sub-record is flattened to .hex strings via mapAttrs.
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
let
  wasm = import "${inputs.self}/lib/wasm.nix" {
    plugins = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.wasm-plugins;
  };
  c = config.theme.data;
  data = wasm.evalNickelFileWith ./helix-zen-theme.ncl {
    dark = builtins.mapAttrs (_: v: v.hex) c.zen.dark;
    light = builtins.mapAttrs (_: v: v.hex) c.zen.light;
  };
in
{
  options.helixZenTheme = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = data;
    description = "Helix zen mode theme colors for distraction-free prose writing";
  };
}
