{
  inputs,
  pkgs,
  ...
}:
let
  tridactyl = pkgs.fetchFirefoxAddon {
    name = "tridactyl";
    url = "https://addons.mozilla.org/firefox/downloads/file/4549492/tridactyl_vim-1.24.4.xpi";
    hash = "sha256:9ba7d6bc3be555631c981c3acdd25cab6942c1f4a6f0cb511bbe8fa81d79dd9d";
    fixedExtid = "tridactyl.vim@cmcaine.co.uk";
  };

  wrappedFirefox =
    (inputs.wrappers.wrapperModules.firefox.apply {
      inherit pkgs;

      extensions = [ tridactyl ];

      nativeMessagingHosts = [ pkgs.tridactyl-native ];

      settings = {
        # Hardware acceleration - WebRender
        "gfx.webrender.all" = true;
        "layers.acceleration.force-enabled" = true;

        # VA-API hardware video decoding (Firefox 137+)
        "media.hardware-video-decoding.force-enabled" = true;
        "media.rdd-ffmpeg.enabled" = true;

        # Wayland-native settings
        "widget.dmabuf.force-enabled" = false;
        "gfx.x11-egl.force-enabled" = false;
      };
    }).wrapper;
in
{
  home.packages = [ wrappedFirefox ];

  # Prevent mimeapps.list backup conflict during home-manager activation
  xdg.configFile."mimeapps.list".force = true;
}
