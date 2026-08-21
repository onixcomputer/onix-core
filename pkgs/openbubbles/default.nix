# OpenBubbles desktop client — serverless iMessage for Linux.
#
# Wraps the official upstream Linux release bundle (a Flutter GTK app) instead
# of building from Flutter source. The upstream bundle is self-contained:
# a `bluebubbles` ELF plus `data/` and `lib/` siblings, including the rustpush
# core (`librust_lib_bluebubbles.so`) and the ObjectBox local store. Keeping
# that three-path layout means the Flutter engine finds its `data/` and `lib/`
# beside the executable. `autoPatchelfHook` resolves the bundled ELF files
# against the system libraries reported by `ldd` on the pinned artifact.
{
  pkgs,
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  gtk3,
  webkitgtk_4_1,
  libsoup_3,
  libnotify,
  libappindicator-gtk3,
  libdbusmenu,
  mpv,
  fontconfig,
}:
let
  version = "1.15.0";

  # Upstream versioned release tag. The Linux bundle asset name and the tag
  # both embed "+205"; pull requests and releases happen on `rustpush`.
  bundleTag = "v${version}%2B205";

  # The bundled media_kit plugins link libmpv.so.1, but nixpkgs mpv 0.41+
  # ships libmpv.so.2 (SONAME bumped upstream). mpv's core client API is
  # stable across the bump, so satisfy the old SONAME with a symlink shim
  # so autoPatchelfHook can resolve the NEEDED entry.
  libmpv1Shim = pkgs.runCommand "libmpv1-shim" { } ''
    mkdir -p $out/lib
    ln -s ${mpv}/lib/libmpv.so.2 $out/lib/libmpv.so.1
  '';
in
stdenv.mkDerivation {
  pname = "openbubbles";
  inherit version;

  src = fetchurl {
    url = "https://github.com/OpenBubbles/openbubbles-app/releases/download/${bundleTag}/bluebubbles-linux-x86_64.tar";
    hash = "sha256-VYSk5529Ivzxm1H7b/ZCbX8TJVVnfhrp00IfBGV7Vjo=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  # System libraries required by the packaged binaries, from `ldd` on the
  # release artifact. gtk3 and webkitgtk_4_1 pull most GTK/GLib leaf deps.
  buildInputs = [
    gtk3
    webkitgtk_4_1
    libsoup_3
    libnotify
    libappindicator-gtk3
    libdbusmenu
    mpv
    libmpv1Shim
    fontconfig
    stdenv.cc.cc.lib # libstdc++
  ];

  sourceRoot = "bundle";
  unpackPhase = ''
    runHook preUnpack
    mkdir -p "bundle"
    tar -xf "$src" -C "bundle"
    sourceRoot="bundle"
    runHook postUnpack
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/libexec/openbubbles" "$out/share/applications" \
      "$out/share/icons/hicolor/256x256/apps"
    cp -r bluebubbles data lib "$out/libexec/openbubbles/"
    chmod +x "$out/libexec/openbubbles/bluebubbles"

    makeWrapper "$out/libexec/openbubbles/bluebubbles" "$out/bin/openbubbles" \
      --prefix LD_LIBRARY_PATH : "$out/libexec/openbubbles/lib"

    if [ -f data/flutter_assets/assets/icon/icon.png ]; then
      install -m0644 data/flutter_assets/assets/icon/icon.png \
        "$out/share/icons/hicolor/256x256/apps/openbubbles.png"
    fi

    cat > "$out/share/applications/openbubbles.desktop" <<EOF
    [Desktop Entry]
    Type=Application
    Name=OpenBubbles
    Comment=Serverless iMessage and Apple services client
    Exec=openbubbles
    Icon=openbubbles
    Terminal=false
    Categories=Network;InstantMessaging;
    Keywords=iMessage;Apple;Messages;
    EOF

    runHook postInstall
  '';

  meta = {
    description = "Serverless iMessage and Apple services client for Linux";
    homepage = "https://openbubbles.app";
    changelog = "https://github.com/OpenBubbles/openbubbles-app/releases/tag/${bundleTag}";
    license = lib.licenses.asl20;
    mainProgram = "openbubbles";
    platforms = [ "x86_64-linux" ];
  };
}
