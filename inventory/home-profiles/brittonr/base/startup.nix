# Startup apps — thin stub over startup.ncl.
#
# Data and contracts live in startup.ncl.
# This module resolves @placeholder@ paths to real store paths
# and exposes the result as readOnly HM options consumed by niri.nix.
{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./startup.ncl;

  # Map @placeholder@ tokens to store paths.
  subs = {
    "@wl-paste@" = "${pkgs.wl-clipboard}/bin/wl-paste";
    "@cliphist@" = "${pkgs.cliphist}/bin/cliphist";
    "@wl-clip-persist@" = "${pkgs.wl-clip-persist}/bin/wl-clip-persist";
    "@polkit-gnome@" = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
    "@nm-applet@" = "${pkgs.networkmanagerapplet}/bin/nm-applet";
    "@blueman-applet@" = "${pkgs.blueman}/bin/blueman-applet";
    "@terminal@" = config.apps.terminal.command;
    "@sysmon@" = config.apps.sysmon.command;
    "@journalctl@" = "${pkgs.systemd}/bin/journalctl";
  };

  resolvePlaceholder = s: subs.${s} or s;

  resolveEntry =
    entry:
    entry
    // {
      command = resolvePlaceholder entry.command;
      args = map resolvePlaceholder entry.args;
    };
in
{
  options.startup = {
    services = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      readOnly = true;
      default = map resolveEntry data.services;
      description = "System services spawned at compositor startup";
    };
    apps = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      readOnly = true;
      default = map resolveEntry data.apps;
      description = "Applications spawned at compositor startup";
    };
  };
}
