{
  lib,
  fetchFromGitHub,
  buildNpmPackage,
  rustPlatform,
  pkg-config,
  gobject-introspection,
  wrapGAppsHook3,
  glib-networking,
  webkitgtk_4_1,
  gtk3,
  glib,
  cairo,
  pango,
  gdk-pixbuf,
  librsvg,
  openssl,
  alsa-lib,
  libsecret,
  libayatana-appindicator,
  gst_all_1,
}:

let
  version = "0.14.1";

  src = fetchFromGitHub {
    owner = "lullabyX";
    repo = "sone";
    rev = "v${version}";
    hash = "sha256-8vdpEjo2UP3vh/PL8+lhLPDfuHeI9kI2/AQvVsWlR1w=";
  };

  gstDeps = with gst_all_1; [
    gstreamer
    gst-plugins-base
    gst-plugins-good
    gst-plugins-bad
    gst-libav
  ];

  libraries = [
    webkitgtk_4_1
    gtk3
    glib
    cairo
    pango
    gdk-pixbuf
    librsvg
    openssl
    alsa-lib
    libsecret
    libayatana-appindicator
  ]
  ++ gstDeps;

  frontend = buildNpmPackage {
    pname = "sone-frontend";
    inherit version src;
    npmDepsHash = "sha256-EOmoryKKWCttpOpIAOpdIz7yOA5hm/Hg1WFbcXWr5tc=";
    buildPhase = ''
      runHook preBuild
      npx tsc && npx vite build
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      cp -r dist $out
      runHook postInstall
    '';
  };
in
rustPlatform.buildRustPackage {
  pname = "sone";
  inherit version src;

  cargoRoot = "src-tauri";
  buildAndTestSubdir = "src-tauri";
  cargoLock.lockFile = "${src}/src-tauri/Cargo.lock";
  cargoBuildFlags = [
    "--features"
    "tauri/custom-protocol"
  ];

  nativeBuildInputs = [
    pkg-config
    gobject-introspection
    wrapGAppsHook3
  ];

  buildInputs = libraries;

  postPatch = ''
    cp -r ${frontend} dist
  '';

  preFixup = ''
    gappsWrapperArgs+=(
      --set GST_PLUGIN_PATH "${lib.makeSearchPath "lib/gstreamer-1.0" gstDeps}"
      --prefix GIO_EXTRA_MODULES : "${glib-networking}/lib/gio/modules"
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libayatana-appindicator ]}"
    )
  '';

  meta = {
    description = "Native Linux client for TIDAL";
    homepage = "https://github.com/lullabyX/sone";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "sone";
  };
}
