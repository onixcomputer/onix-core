# Default applications — thin stub over apps.ncl.
#
# Data and contracts live in apps.ncl.
# This module resolves @placeholder@ tokens to store paths and
# exposes each app as a readOnly HM option.
{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./apps.ncl;

  subs = {
    "@wezterm@" = "${pkgs.wezterm}/bin/wezterm";
  };

  resolvePlaceholder = s: subs.${s} or s;

  resolveApp =
    app:
    app
    // {
      command = resolvePlaceholder app.command;
    };

  mkAppOption =
    description: app:
    lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = resolveApp app;
      inherit description;
    };
in
{
  options.apps = {
    terminal = mkAppOption "Default terminal emulator" data.terminal;
    browser = mkAppOption "Default web browser" data.browser;
    fileManager = mkAppOption "Default file manager" data.fileManager;
    sysmon = mkAppOption "Default system monitor" data.sysmon;
  };
}
