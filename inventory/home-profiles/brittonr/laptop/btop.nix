{ config, ... }:
{
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "onix-tokyo-night";
      theme_background = false;
      vim_keys = true;
    };
  };

  xdg.configFile."btop/themes/onix-tokyo-night.theme".text = config.btopTheme;
}
