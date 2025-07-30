{ pkgs, ... }:

{
  programs.lutris = {
    enable = true;

    extraPackages = with pkgs; [
      # Graphics libraries
      vulkan-tools
      vulkan-loader
      vulkan-validation-layers
      mesa
      mesa-demos

      # Audio
      pipewire
      pulseaudio
      alsa-lib
      alsa-plugins

      # Controllers
      gamemode
      gamescope
      mangohud

      # Additional runtime dependencies
      libgdiplus
      gnutls
      openldap
      libxml2
      libxslt
      libva
      gtk3
      gdk-pixbuf

      # Media codecs
      ffmpeg
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-ugly
    ];

    winePackages = with pkgs; [
      wineWowPackages.staging
      wineWowPackages.waylandFull
      winetricks
    ];

    protonPackages = with pkgs; [
      proton-ge-bin
    ];

    runners = {
      wine = {
        enable = true;
        package = pkgs.wineWowPackages.staging;
      };

      steam = {
        enable = true;
      };

      dosbox = {
        enable = true;
      };

      scummvm = {
        enable = true;
      };

      retroarch = {
        enable = true;
      };
    };
  };
}
