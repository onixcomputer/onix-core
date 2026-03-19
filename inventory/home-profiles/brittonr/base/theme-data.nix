# Base theme data option — available to all profiles (server and desktop).
#
# Provides theme.allData (lazy attrset mapping theme name → evaluated NCL data)
# and theme.data (the active theme's data). Each theme is a separate thunk —
# server machines only force the active theme (1 WASM call), desktop machines
# force all themes for wallpaper symlinking (5 calls).
#
# Desktop machines override theme.data via the full theme.nix module.
# Server machines get the default (active theme NCL data) without the desktop
# GTK/Qt/wallpaper integration.
{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:
let
  wasm = import "${inputs.self}/lib/wasm.nix" {
    plugins = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.wasm-plugins;
  };

  themesDir = ../../shared/desktop/themes;
  themeNames = [
    "tokyo-night"
    "onix-dark"
    "onix-light"
    "everblush"
    "solarized-dark"
  ];

  # Lazy: each value is a separate thunk, only forced on access.
  allThemeData = lib.genAttrs themeNames (name: wasm.evalNickelFile (themesDir + "/${name}.ncl"));
in
{
  options.theme = {
    active = lib.mkOption {
      type = lib.types.enum themeNames;
      default = "onix-dark";
      description = "The active theme name";
    };

    allData = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = allThemeData;
      internal = true;
      description = "Lazy attrset of all theme NCL data, keyed by theme name. Shared across profiles.";
    };

    data = lib.mkOption {
      type = lib.types.attrs;
      default = config.theme.allData.${config.theme.active};
      description = "Full theme data from NCL export. Desktop profiles enrich this with package fields.";
    };

    autoSetMatchingWallpaper = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Automatically set matching wallpaper when theme changes";
    };
  };
}
