{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  meson,
  ninja,
  expat,
  curl,
  libmicrohttpd,
}:

stdenv.mkDerivation rec {
  pname = "libnpupnp";
  version = "6.2.3";

  src = fetchurl {
    url = "https://www.lesbonscomptes.com/upmpdcli/downloads/${pname}-${version}.tar.gz";
    hash = "sha256-Vj0qnkr+YDcXND3EZnwLicagFwCKxrUiYtoXoeT2u5Y=";
  };

  nativeBuildInputs = [
    pkg-config
    meson
    ninja
  ];
  buildInputs = [
    expat
    curl
    libmicrohttpd
  ];

  meta = with lib; {
    description = "A C++ base UPnP library, derived from Portable UPnP, a.k.a libupnp";
    homepage = "https://www.lesbonscomptes.com/upmpdcli/npupnp-doc/libnpupnp.html";
    license = licenses.bsd3;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
