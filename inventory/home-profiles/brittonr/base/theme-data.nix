# Base theme data option — available to all profiles (server and desktop).
#
# Desktop machines override this via the full theme.nix module.
# Server machines get the default (onix-dark) without the desktop
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

  activeThemeData = wasm.evalNickelFile (themesDir + "/${config.theme.active}.ncl");
in
{
  options.theme = {
    active = lib.mkOption {
      type = lib.types.enum themeNames;
      default = "onix-dark";
      description = "The active theme name";
    };

    data = lib.mkOption {
      type = lib.types.attrs;
      default = activeThemeData;
      description = "Full theme data from NCL export. Desktop profiles enrich this with package fields.";
    };

    autoSetMatchingWallpaper = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Automatically set matching wallpaper when theme changes";
    };
  };
}
