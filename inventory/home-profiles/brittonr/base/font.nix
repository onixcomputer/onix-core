{ lib, ... }:
{
  options.font = {
    mono = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "CaskaydiaMono Nerd Font Mono";
      description = "Monospace font for terminals and code editors";
    };

    ui = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "CaskaydiaMono Nerd Font";
      description = "UI font for bars, notifications, menus";
    };

    size = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = {
        terminal = 12;
        notification = 11;
        bar = 13;
        small = 11;
      };
      description = "Font sizes by context";
    };
  };
}
