{ pkgs, config, ... }:
let
  c = config.theme.data;
  mkBatTmTheme = import ../../shared/lib/mk-bat-theme.nix;
in
{
  programs.bat = {
    enable = true;
    config = {
      pager = "never";
      style = "numbers,changes,header";
      theme = "onix-dark";
    };
    themes = {
      onix-dark = {
        src = pkgs.writeText "onix-dark.tmTheme" (mkBatTmTheme {
          name = "Onix Dark";
          colors = {
            bg = c.bg.hex;
            fg = c.fg.hex;
            orange = c.orange.hex;
            blue = c.blue.hex;
            cyan = c.cyan.hex;
            green = c.green.hex;
            yellow = c.yellow.hex;
            red = c.red.hex;
            comment = c.comment.hex;
            bg_highlight = c.bg_highlight.hex;
            border = c.border.hex;
          };
        });
        file = "onix-dark.tmTheme";
      };
    };
  };
}
