{ pkgs, ... }:
{
  # Minimal font setup - only what we actually use
  home.packages = with pkgs; [
    # Primary font with Nerd Font icons
    nerd-fonts.caskaydia-mono

    # Color emoji support
    noto-fonts-color-emoji

    # CJK (Chinese, Japanese, Korean) support - good to have
    noto-fonts-cjk-sans
  ];

  # User-level fontconfig
  fonts.fontconfig.enable = true;

  xdg.configFile."fontconfig/conf.d/10-fonts.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
    <fontconfig>
      <!-- Set preferred fonts -->
      <alias>
        <family>monospace</family>
        <prefer>
          <family>CaskaydiaMono Nerd Font</family>
          <family>Noto Color Emoji</family>
          <family>Noto Sans CJK</family>
        </prefer>
      </alias>
      
      <alias>
        <family>sans-serif</family>
        <prefer>
          <family>Noto Sans</family>
          <family>Noto Color Emoji</family>
          <family>Noto Sans CJK</family>
        </prefer>
      </alias>
      
      <!-- Ensure color emoji is used -->
      <alias>
        <family>emoji</family>
        <prefer>
          <family>Noto Color Emoji</family>
        </prefer>
      </alias>
    </fontconfig>
  '';
}
