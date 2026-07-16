{
  stdenvNoCC,
  source,
}:
stdenvNoCC.mkDerivation {
  pname = "ttwkv7-kernels";
  inherit (source) version;

  src = source.upstream;
  patches = [ ./use-architecture-sfpu-helpers.patch ];

  postPatch = ''
    cp ${./constant-tile-probe-compute.cpp} kernels/ttwkv7_constant_tile_compute.cpp
    cp ${./constant-tile-probe-writer.cpp} kernels/ttwkv7_constant_tile_writer.cpp
    cp ${./data-movement-capture-writer.cpp} kernels/ttwkv7_data_movement_capture_writer.cpp
    cp ${./data-movement-capture-source-reader.cpp} kernels/ttwkv7_data_movement_capture_source_reader.cpp
    cp ${./data-movement-source-reader.cpp} kernels/ttwkv7_data_movement_source_reader.cpp
  '';

  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/ttwkv7"
    cp -R kernels "$out/share/ttwkv7/kernels"
    runHook postInstall
  '';
}
