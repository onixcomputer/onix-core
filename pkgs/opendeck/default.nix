{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  openssl,
  fontconfig,
  systemdLibs,
  gtk3,
  gdk-pixbuf,
  cairo,
  glib,
  webkitgtk_4_1,
  libsoup_3,
  libxkbcommon,
  libxcb,
  libayatana-appindicator,
}:

stdenv.mkDerivation rec {
  pname = "opendeck";
  version = "2.10.1";

  src = fetchurl {
    url = "https://github.com/nekename/OpenDeck/releases/download/v${version}/opendeck_${version}_amd64.deb";
    hash = "sha256-wnIcbkxph70naI9ewy9NaAgXDNLsXejO+mW0VDksTPo=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    openssl
    fontconfig
    systemdLibs # libudev
    gtk3
    gdk-pixbuf
    cairo
    glib
    webkitgtk_4_1
    libsoup_3
    libxkbcommon
    libxcb
    libayatana-appindicator
  ];

  unpackPhase = ''
    ar x $src
    tar xzf data.tar.gz
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib $out/share

    cp -r usr/bin/opendeck $out/bin/opendeck
    cp -r usr/lib/opendeck $out/lib/opendeck
    cp -r usr/share/* $out/share/

    # Patch the bundled plugin binary too
    autoPatchelf $out/lib/opendeck

    # libayatana-appindicator3 is dlopen'd at runtime for tray icon support.
    # GDK_BACKEND=x11 forces Xwayland — GTK3/WebKitGTK can't handle fractional
    # Wayland scales (e.g. 1.5x), which makes the Stream Deck button grid tiny.
    wrapProgram $out/bin/opendeck \
      --set GDK_BACKEND x11 \
      --set WEBKIT_DISABLE_DMABUF_RENDERER 1 \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libayatana-appindicator ]}"

    runHook postInstall
  '';

  meta = {
    description = "Linux software for Elgato Stream Deck controllers";
    homepage = "https://github.com/nekename/OpenDeck";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "opendeck";
  };
}
