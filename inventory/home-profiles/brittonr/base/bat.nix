{ pkgs, config, ... }:
let
  c = config.colors;
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
            inherit (c)
              bg
              fg
              orange
              blue
              cyan
              green
              yellow
              red
              comment
              bg_highlight
              border
              ;
          };
        });
        file = "onix-dark.tmTheme";
      };
    };
  };
}
