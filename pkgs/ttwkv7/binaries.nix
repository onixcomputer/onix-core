{
  stdenv,
  cmake,
  ninja,
  fmt,
  libblake3,
  nlohmann_json,
  spdlog,
  enchantum,
  tt-logger,
  tt-metal,
  source,
}:
# r[impl onix.tenstorrent.native_runtime.ttwkv7.checkpoint_shape]
stdenv.mkDerivation {
  pname = "ttwkv7-binaries";
  inherit (source) version;

  src = source.upstream;
  patches = [
    ./use-installed-metalium.patch
    ./support-checkpoint-host-shape.patch
    ./share-checkpoint-host-layout.patch
    ./share-decode-runtime-abi.patch
  ];

  postPatch = ''
    cp ${./constant-tile-probe.cpp} constant-tile-probe.cpp
    cp ${./data-movement-probe.cpp} data-movement-probe.cpp
    cp ${./rwkv-host-layout-validator.cpp} rwkv-host-layout-validator.cpp
    cp ${./rwkv-decode-reader-validator.cpp} rwkv-decode-reader-validator.cpp
    cp ${./ttwkv7-host-layout.h} ttwkv7-host-layout.h
    cp ${./ttwkv7-decode-abi.h} ttwkv7-decode-abi.h
    cp wkv7_runner.cpp "$TMPDIR/ttwkv7-patched-wkv7-runner.cpp"
  '';

  strictDeps = true;
  nativeBuildInputs = [
    cmake
    ninja
  ];
  buildInputs = [
    enchantum
    fmt
    libblake3
    nlohmann_json
    spdlog
    tt-logger
    tt-metal
  ];

  postInstall = ''
    rm -rf "$out/share"
    mkdir -p "$out/share/ttwkv7/source"
    cp "$TMPDIR/ttwkv7-patched-wkv7-runner.cpp" "$out/share/ttwkv7/source/wkv7_runner.cpp"
    cp ${./rwkv-host-layout-validator.cpp} "$out/share/ttwkv7/source/rwkv-host-layout-validator.cpp"
    cp ${./rwkv-decode-reader-validator.cpp} "$out/share/ttwkv7/source/rwkv-decode-reader-validator.cpp"
    cp ${./ttwkv7-host-layout.h} "$out/share/ttwkv7/source/ttwkv7-host-layout.h"
    cp ${./ttwkv7-decode-abi.h} "$out/share/ttwkv7/source/ttwkv7-decode-abi.h"
    test -x "$out/libexec/ttwkv7/wkv7"
    test -x "$out/libexec/ttwkv7/wkv7-constant-probe"
    test -x "$out/libexec/ttwkv7/wkv7-data-movement-probe"
    test -x "$out/libexec/ttwkv7/wkv7-rwkv-host-layout-validator"
    test -x "$out/libexec/ttwkv7/wkv7-rwkv-decode-reader-validator"
  '';
}
