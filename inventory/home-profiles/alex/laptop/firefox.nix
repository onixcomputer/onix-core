_: {
  programs.firefox = {
    enable = true;

    # Profiles with WebGL and hardware acceleration settings
    profiles.default = {
      isDefault = true;
      settings = {
        # WebGL configuration - ensure it's enabled
        "webgl.disabled" = false;
        "webgl.force-enabled" = true;
        "webgl.msaa-force" = true;

        # Hardware acceleration - WebRender
        "gfx.webrender.all" = true;
        "layers.acceleration.force-enabled" = true;

        # VA-API hardware video decoding (Firefox 137+)
        # Note: media.ffmpeg.vaapi.enabled is deprecated since Firefox 137
        "media.hardware-video-decoding.force-enabled" = true;
        "media.rdd-ffmpeg.enabled" = true;

        # Wayland-native: don't force dmabuf or x11-egl
        # Let Firefox auto-detect the correct backend
        "widget.dmabuf.force-enabled" = false;
        "gfx.x11-egl.force-enabled" = false;
      };
    };
  };
}
