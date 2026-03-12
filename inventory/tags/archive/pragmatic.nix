{
  pkgs,
  lib,
  config,
  ...
}:
{
  services = {
    # A fuse filesystem that dynamically populates contents of /bin
    # and /usr/bin/ so that it contains all executables from the PATH
    # of the requesting process.
    envfs.enable = true;
  };

  programs = {
    # Run unpatched Linux binaries (AppImages, downloaded tools, etc.)
    # without containers. The library list covers most common dependencies.
    nix-ld = {
      enable = true;
      libraries =
        with pkgs;
        [
          acl
          attr
          bzip2
          dbus
          expat
          fontconfig
          freetype
          fuse3
          icu
          libnotify
          libsodium
          libssh
          libunwind
          libusb1
          libuuid
          nspr
          nss
          stdenv.cc.cc
          util-linux
          zlib
          zstd
        ]
        ++ lib.optionals (config.hardware.graphics.enable or false) [
          pipewire
          cups
          libxkbcommon
          pango
          mesa
          libdrm
          libglvnd
          libpulseaudio
          atk
          cairo
          alsa-lib
          at-spi2-atk
          at-spi2-core
          gdk-pixbuf
          glib
          gtk3
          libGL
          libappindicator-gtk3
          vulkan-loader
          xorg.libX11
          xorg.libxshmfence
          xorg.libXScrnSaver
          xorg.libXcomposite
          xorg.libXcursor
          xorg.libXdamage
          xorg.libXext
          xorg.libXfixes
          xorg.libXi
          xorg.libXrandr
          xorg.libXrender
          xorg.libXtst
          libxcb
          xorg.libxkbfile
        ];
    };
  };
}
