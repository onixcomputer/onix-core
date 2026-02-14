{ lib, pkgs, ... }:
{
  options.cursor = {
    name = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "phinger-cursors-dark";
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
      default = 24;
      description = "Cursor size in pixels";
    };
  };
}
