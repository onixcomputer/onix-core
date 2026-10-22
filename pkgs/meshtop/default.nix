{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "meshtop";
  version = "0.1.0";

  src = ./source;
  cargoLock.lockFile = ./source/Cargo.lock;

  passthru.sourceRevision = lib.trim (builtins.readFile ./SOURCE_REVISION);

  meta = {
    description = "Read-only multi-host terminal system monitor over Iroh";
    mainProgram = "meshtop";
    platforms = lib.platforms.linux;
    # The upstream Cargo.toml does not declare a license.
  };
}
