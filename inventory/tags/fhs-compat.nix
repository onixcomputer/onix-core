{
  config,
  lib,
  pkgs,
  ...
}:
{
  # nix-ld provides a dynamic linker shim so unpatched Linux binaries
  # (AppImages, vendored CLIs, downloaded tools) can find their interpreter.
  programs.nix-ld.enable = true;

  programs.nix-ld.libraries =
    with pkgs;
    [
      # C runtime / compression / crypto
      acl
      attr
      bzip2
      expat
      fuse3
      icu
      libsodium
      libssh
      libunwind
      libuuid
      nspr
      nss
      stdenv.cc.cc
      util-linux
      zlib
      zstd

      # D-Bus / desktop plumbing
      dbus

      # Fonts
      fontconfig
      freetype

      # USB
      libusb1

      # Notifications
      libnotify
    ]
    ++ lib.optionals config.hardware.graphics.enable [
      # Audio
      alsa-lib
      libpulseaudio
      pipewire

      # Printing
      cups

      # Graphics / GPU
      mesa
      libdrm
      libglvnd
      libGL
      vulkan-loader

      # Wayland / X11 client libs
      libxkbcommon
      libxcb
      libxkbfile
      libxshmfence
      libx11
      libxcomposite
      libxcursor
      libxdamage
      libxext
      libxfixes
      libxi
      libxrandr
      libxrender
      libxtst

      # GTK / widget toolkit
      pango
      atk
      cairo
      gdk-pixbuf
      glib
      gtk3
      at-spi2-atk
      at-spi2-core
      libappindicator-gtk3
    ];

  # envfs populates /usr/bin/env and other FHS paths so scripts with
  # shebangs like #!/usr/bin/env python3 work without wrappers.
  services.envfs.enable = true;
}
