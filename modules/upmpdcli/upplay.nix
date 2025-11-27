{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  libsForQt5,
  libupnpp,
  libnpupnp,
  expat,
  jsoncpp,
  curl,
}:

stdenv.mkDerivation rec {
  pname = "upplay";
  version = "1.7.10";

  src = fetchurl {
    url = "https://www.lesbonscomptes.com/upplay/downloads/${pname}-${version}.tar.gz";
    hash = "sha256-nLcP8Vi3S2qLrR3ScnUVRh8mzEaRLxxnyvPi7znV2hE=";
  };

  nativeBuildInputs = [
    pkg-config
    libsForQt5.wrapQtAppsHook
  ];

  buildInputs = [
    libsForQt5.qtbase
    libsForQt5.qtwebengine
    libupnpp
    libnpupnp
    expat
    jsoncpp
    curl
  ];

  # Qt5 application
  dontWrapQtApps = false;

  preConfigure = ''
    export QMAKE_LRELEASE=${libsForQt5.qtbase.dev}/bin/lrelease
  '';

  configurePhase = ''
    runHook preConfigure
    qmake PREFIX=$out upplay.pro
    runHook postConfigure
  '';

  meta = with lib; {
    description = "Qt-based UPnP audio control point";
    longDescription = ''
      Upplay is a desktop UPnP audio Control Point for Linux/Unix, MS Windows, and Mac OS.
      It began its existence as a companion to the Upmpdcli renderer, but has become a
      lightweight but capable control point in its own right.
    '';
    homepage = "https://www.lesbonscomptes.com/upplay/";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
  };
}
