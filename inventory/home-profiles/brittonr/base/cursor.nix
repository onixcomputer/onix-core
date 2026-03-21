# Cursor theme — thin stub over cursor.ncl.
#
# Data and contracts live in cursor.ncl.
# The package reference stays here since Nickel can't resolve Nix packages.
{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./cursor.ncl;
in
{
  options.cursor = {
    name = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = data.name;
      description = "Cursor theme name";
    };

    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = pkgs.phinger-cursors;
      description = "Cursor theme package";
    };

    size = lib.mkOption {
      type = lib.types.int;
      readOnly = true;
      default = data.size;
      description = "Cursor size in pixels";
    };
  };
}
