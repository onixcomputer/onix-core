{ pkgs, ... }:
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  security.polkit.enable = true;

  xdg.portal.enable = true;

  fonts = {
    packages = with pkgs; [
      noto-fonts
      noto-fonts-emoji
      noto-fonts-cjk-sans
      liberation_ttf
      nerd-fonts.jetbrains-mono
      nerd-fonts.caskaydia-mono
      dejavu_fonts # Fallback fonts
    ];

    # Enable font configuration
    fontconfig = {
      enable = true;
      defaultFonts = {
        serif = [
          "Noto Serif"
          "Liberation Serif"
          "DejaVu Serif"
        ];
        sansSerif = [
          "Noto Sans"
          "Liberation Sans"
          "DejaVu Sans"
        ];
        monospace = [
          "CaskaydiaMono Nerd Font"
          "JetBrainsMono Nerd Font"
          "DejaVu Sans Mono"
        ];
        emoji = [ "Noto Color Emoji" ];
      };

      # Better font rendering
      antialias = true;
      hinting = {
        enable = true;
        style = "slight";
      };
      subpixel.lcdfilter = "default";
    };
  };
}
