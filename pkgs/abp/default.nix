{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  gcc-unwrapped,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  libgbm,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  nspr,
  nss,
  pango,
  systemd,
  vulkan-loader,
}:

let
  version = "0.1.6";
in
stdenv.mkDerivation {
  pname = "abp";
  inherit version;

  src = fetchurl {
    url = "https://github.com/theredsix/agent-browser-protocol/releases/download/v${version}/abp-${version}-linux-x64.tar.gz";
    hash = "sha256-XflCqT9wlUN5Y7n1Lykim5sKGmH5/2jMIQnxnXfTI+Y=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    gcc-unwrapped.lib
    glib
    libgbm
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    pango
    systemd
    vulkan-loader
  ];

  # Qt shim libraries are optional (Chromium falls back to GTK dialogs)
  autoPatchelfIgnoreMissingDeps = [
    "libQt5Core.so.5"
    "libQt5Gui.so.5"
    "libQt5Widgets.so.5"
    "libQt6Core.so.6"
    "libQt6Gui.so.6"
    "libQt6Widgets.so.6"
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/abp $out/bin
    cp -r abp-chrome/* $out/lib/abp/

    # Replace bundled vulkan-loader with system one
    rm -f $out/lib/abp/libvulkan.so.1
    ln -s "${lib.getLib vulkan-loader}/lib/libvulkan.so.1" "$out/lib/abp/libvulkan.so.1"

    makeWrapper "$out/lib/abp/abp" "$out/bin/abp" \
      --add-flags "--no-sandbox" \
      --add-flags "--disable-setuid-sandbox"

    runHook postInstall
  '';

  meta = {
    description = "Chromium build with MCP + REST baked in for AI agent browser automation";
    homepage = "https://github.com/theredsix/agent-browser-protocol";
    license = lib.licenses.bsd3;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "abp";
  };
}
