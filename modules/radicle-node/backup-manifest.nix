{ pkgs }:
pkgs.rustPlatform.buildRustPackage {
  pname = "radicle-backup-manifest";
  version = "0.1.0";

  src = pkgs.lib.cleanSource ./backup-manifest;
  cargoLock.lockFile = ./backup-manifest/Cargo.lock;

  doCheck = true;
  strictDeps = true;
}
