# Keymap options — thin stub over keymap.ncl.
#
# Data and contracts live in keymap.ncl.
# This module exposes the data as readOnly HM options so other
# modules can reference config.keymap.*.
{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  wasm = import "${inputs.self}/lib/wasm.nix" {
    plugins = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.wasm-plugins;
  };
  data = wasm.evalNickelFile ./keymap.ncl;
in
{
  options.keymap = lib.mapAttrs (
    _name: value:
    lib.mkOption {
      type = if builtins.isString value then lib.types.str else lib.types.attrs;
      readOnly = true;
      default = value;
    }
  ) data;
}
