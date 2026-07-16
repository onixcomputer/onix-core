{
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "tt-vibethinker-bench";
  version = "0.1.0";

  src = lib.cleanSource ./.;

  cargoLock.lockFile = ./Cargo.lock;

  meta = {
    description = "Validated VibeThinker benchmark matrix for two P150 cards";
    license = lib.licenses.mit;
    mainProgram = "tt-vibethinker-bench";
    platforms = lib.platforms.linux;
  };
}
