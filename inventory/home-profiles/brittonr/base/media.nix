# Media player settings — thin stub over media.ncl.
#
# Data and contracts live in media.ncl.
# Theme-dependent values (subtitles.color, subtitles.borderColor, cava.gradient)
# are merged here from config.theme.data since themes are resolved at Nix eval time.
{
  inputs,
  lib,
  config,
  ...
}:
let
  plugins = inputs.self.packages.x86_64-linux.wasm-plugins;
  wasm = import "${inputs.self}/lib/wasm.nix" { inherit plugins; };
  data = wasm.evalNickelFile ./media.ncl;

  c = config.theme.data;
  r = c.rainbow;
in
{
  options.media = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = data // {
      # Subtitle colors from active theme
      subtitles = {
        color = "#FF${c.grayscale.white.no_hash}";
        borderColor = "#FF${c.editor.black.no_hash}";
      };

      # Cava with theme-dependent gradient colors
      cava = data.cava // {
        gradient = [
          "'${r.green.hex}'"
          "'${r.cyan.hex}'"
          "'${r.blue.hex}'"
          "'${r.yellow.hex}'"
          "'${r.orange.hex}'"
          "'${r.red.hex}'"
          "'${r.violet.hex}'"
          "'${r.red.hex}'" # repeated for 8-entry gradient
        ];
      };
    };
    description = "Media player and visualizer settings";
  };
}
