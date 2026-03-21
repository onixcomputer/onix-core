# User settings — thin stub over settings.ncl.
#
# Data and contracts live in settings.ncl.
# This module exposes each top-level key as a readOnly HM option
# so other modules can reference config.<key>.
{
  inputs,
  lib,
  ...
}:
let
  # Use a fixed system — settings.ncl is pure data, no platform dependency.
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./settings.ncl;

  mkReadOnly =
    value:
    lib.mkOption {
      type =
        if builtins.isAttrs value then
          lib.types.attrs
        else if builtins.isList value then
          lib.types.listOf lib.types.anything
        else if builtins.isString value then
          lib.types.str
        else if builtins.isInt value || builtins.isFloat value then
          lib.types.number
        else if builtins.isBool value then
          lib.types.bool
        else
          lib.types.anything;
      readOnly = true;
      default = value;
    };
in
{
  options = builtins.mapAttrs (_: mkReadOnly) data;
}
