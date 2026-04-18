{
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "hx-oil";
  version = "0.1.0";

  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;

  meta = {
    description = "Oil-style editable directory manifests for wrapped Helix";
    license = lib.licenses.mit;
    mainProgram = "hx-oil";
    platforms = lib.platforms.unix;
  };
}
