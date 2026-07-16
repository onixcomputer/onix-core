{
  stdenv,
  cmake,
  ninja,
  fmt,
  nlohmann_json,
  spdlog,
  enchantum,
  tt-logger,
  tt-metal,
  source,
}:
stdenv.mkDerivation {
  pname = "ttwkv7-binaries";
  inherit (source) version;

  src = source.upstream;
  patches = [ ./use-installed-metalium.patch ];

  postPatch = ''
    cp ${./constant-tile-probe.cpp} constant-tile-probe.cpp
  '';

  strictDeps = true;
  nativeBuildInputs = [
    cmake
    ninja
  ];
  buildInputs = [
    enchantum
    fmt
    nlohmann_json
    spdlog
    tt-logger
    tt-metal
  ];

  postInstall = ''
    rm -rf "$out/share"
    test -x "$out/libexec/ttwkv7/wkv7"
    test -x "$out/libexec/ttwkv7/wkv7-constant-probe"
  '';
}
