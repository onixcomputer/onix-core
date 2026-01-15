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

        # Hardware acceleration
        "gfx.webrender.all" = true;
        "gfx.webrender.compositor.force-enabled" = true;
        "layers.acceleration.force-enabled" = true;
        "media.ffmpeg.vaapi.enabled" = true;
        "media.hardware-video-decoding.force-enabled" = true;

        # Wayland-specific optimizations
        "widget.dmabuf.force-enabled" = true;

        # EGL backend for better Wayland/NVIDIA support
        "gfx.x11-egl.force-enabled" = false; # Disable X11 EGL, use Wayland
      };
    };
  };
}
