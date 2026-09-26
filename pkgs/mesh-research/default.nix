{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "onix-mesh-research";
  version = "0.1.0";
  src = lib.cleanSource ./.;

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes."mesh-llm-plugin-0.72.2" = "sha256-9PJhO15NKU3Cd2sDKMUlr7by2BXs4S8s0o8pteS1xf4=";
  };

  meta = {
    description = "Native Mesh-LLM research operations and authenticated peer HTTP streams";
    license = lib.licenses.asl20;
    mainProgram = "onix-mesh-research";
    platforms = lib.platforms.linux;
  };
}
