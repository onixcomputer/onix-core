{
  inputs,
  pkgs,
  config,
  ...
}:
let
  c = config.theme.data;
  wasm = import "${inputs.self}/lib/wasm.nix" {
    plugins = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.wasm-plugins;
  };
  activeTheme = config.theme.active;
  batThemeXml = wasm.evalNickelFileWith ../../shared/lib/mk-bat-theme.ncl {
    inherit (config.theme.data) name;
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
  };
in
{
  programs.bat = {
    enable = true;
    config = {
      pager = "never";
      style = "numbers,changes,header";
      theme = activeTheme;
    };
    themes = {
      ${activeTheme} = {
        src = pkgs.writeTextDir "${activeTheme}.tmTheme" batThemeXml;
        file = "${activeTheme}.tmTheme";
      };
    };
  };
}
