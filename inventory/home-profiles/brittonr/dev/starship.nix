# Starship prompt — thin stub over starship.ncl.
#
# Theme colors flattened to simple strings — full theme data is too
# large for WASM stack when serialized as Nickel source text.
{
  inputs,
  config,
  pkgs,
  ...
}:
let
  wasm = import "${inputs.self}/lib/wasm.nix" {
    plugins = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.wasm-plugins;
  };
  c = config.theme.data;
  settings = wasm.evalNickelFileWith ./starship.ncl {
    grayscale_white = c.grayscale.white.hex;
    grayscale_light = c.grayscale.light.hex;
    grayscale_medium = c.grayscale.medium.hex;
    grayscale_dim = c.grayscale.dim.hex;
    grayscale_muted = c.grayscale.muted.hex;
    editor_type_dark = c.editor.type_dark.hex;
    bg = c.bg.hex;
    bg_highlight = c.bg_highlight.hex;
    fg = c.fg.hex;
    docker_accent = c.misc.docker_accent.hex;
    paletteName = config.theme.active;
    inherit (config.shellConfig.starship) truncationLength cmdDurationMinTime;
  };
in
{
  programs.starship = {
    enable = true;
    enableInteractive = true;
    enableTransience = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    inherit settings;
  };

  # Force-overwrite so HM doesn't fail when a .hm-bak already exists
  # from a prior activation.  programs.starship uses home.file with
  # the full configPath, not xdg.configFile.
  home.file.${config.programs.starship.configPath}.force = true;
}
