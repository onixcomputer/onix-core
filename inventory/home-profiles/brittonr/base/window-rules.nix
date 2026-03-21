# Window rules — thin stub over window-rules.ncl.
#
# Data and contracts live in window-rules.ncl.
# This module resolves @placeholder@ tokens and exposes the result
# as readOnly HM options consumed by niri.nix.
{
  inputs,
  config,
  lib,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./window-rules.ncl;

  subs = {
    "@sysmon-title@" = "^${config.apps.sysmon.name}$";
  };

  resolvePlaceholder = s: subs.${s} or s;

  resolveOverride =
    entry:
    entry
    // {
      title = resolvePlaceholder entry.title;
    };
in
{
  options.windowRules = {
    assignments = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      readOnly = true;
      default = data.assignments;
      description = "Workspace assignments by app-id regex";
    };
    titleOverrides = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      readOnly = true;
      default = map resolveOverride data.titleOverrides;
      description = "App-specific overrides matched by title within an app-id";
    };
  };
}
