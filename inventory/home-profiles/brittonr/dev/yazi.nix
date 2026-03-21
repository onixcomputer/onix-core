{ pkgs, ... }:
{
  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
    shellWrapperName = "y";

    settings = {
      preview = {
        max_width = 1920;
        max_height = 1080;
        cache_dir = "";
      };
      opener = {
        open = [
          {
            run = ''xdg-open "$@"'';
            orphan = true;
            desc = "Open";
          }
        ];
      };
    };
  };

  # Preview dependencies — yazi shells out to these for rich file previews
  home.packages = with pkgs; [
    file # MIME type detection
    unar # Archive preview
    poppler-utils # PDF to image (pdftoppm)
    ffmpegthumbnailer # Video thumbnails
    imagemagick # Image conversion / SVG preview
    jq # JSON pretty-print
  ];
}
