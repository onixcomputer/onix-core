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

        # Disable AV1 - prevents fallback to software decode on older NVIDIA
        # RTX 30+ supports AV1, but can cause issues with nvidia-vaapi-driver
        "media.av1.enabled" = false;

        # Disable WebRTC VA-API to prevent video call artifacts
        "media.navigator.mediadatadecoder_vpx_enabled" = false;

        # Wayland-specific optimizations
        "widget.dmabuf.force-enabled" = true;

        # EGL backend - required for nvidia-vaapi-driver
        "gfx.x11-egl.force-enabled" = true;
      };
    };
  };
}
