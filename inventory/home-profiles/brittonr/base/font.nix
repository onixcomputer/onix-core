{ lib, ... }:
{
  options.font = {
    mono = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "CaskaydiaMono Nerd Font";
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

    stacks = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      default = {
        sans = [
          "Noto Sans"
          "Liberation Sans"
          "DejaVu Sans"
        ];
        serif = [
          "Noto Serif"
          "Liberation Serif"
          "DejaVu Serif"
        ];
        monospace = [
          "CaskaydiaMono Nerd Font"
          "Berkeley Mono"
          "Liberation Mono"
          "DejaVu Sans Mono"
        ];
        emoji = [ "Noto Color Emoji" ];
        cjk = [ "Noto Sans CJK" ];
        subtitle = "Liberation Sans";
      };
      description = "Font family stacks for fontconfig and application defaults";
    };
  };
}
