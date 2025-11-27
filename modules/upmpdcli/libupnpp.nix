{
  lib,
  stdenv,
  fetchurl,
  pkg-config,
  meson,
  ninja,
  expat,
  curl,
  libnpupnp,
}:

stdenv.mkDerivation rec {
  pname = "libupnpp";
  version = "1.0.3";

  src = fetchurl {
    url = "https://www.lesbonscomptes.com/upmpdcli/downloads/${pname}-${version}.tar.gz";
    hash = "sha256-07IBYZqEg3J53Ebut8yqp5YNQ3LbEbQ88rFDtdm9Mi4=";
  };

  nativeBuildInputs = [
    pkg-config
    meson
    ninja
  ];
  buildInputs = [
    expat
    curl
    libnpupnp
  ];

  meta = with lib; {
    description = "Application-oriented C++ layer over the libnpupnp base UPnP library";
    homepage = "https://www.lesbonscomptes.com/upmpdcli/libupnpp-refdoc/libupnpp-ctl.html";
    license = licenses.lgpl21Plus;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
