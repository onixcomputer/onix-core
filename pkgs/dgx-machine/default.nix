{
  lib,
  rustPlatform,
  makeWrapper,
  devenv,
  machineInventory,
}:
let
  inventory = builtins.fromJSON (builtins.readFile machineInventory);
  machineNames = lib.sort lib.lessThan (builtins.attrNames inventory.machines);
  encodedMachineNames = lib.concatStringsSep "\n" machineNames;
in
rustPlatform.buildRustPackage {
  pname = "dgx-machine";
  version = "0.1.0";
  src = ./.;

  cargoLock.lockFile = ./Cargo.lock;
  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram "$out/bin/dgx-machine" \
      --set DGX_DEVENV_BIN ${lib.escapeShellArg (lib.getExe devenv)} \
      --set DGX_MACHINE_NAMES ${lib.escapeShellArg encodedMachineNames}
  '';

  meta = {
    description = "Device-free command shell for Devenv-owned DGX machines";
    license = lib.licenses.mit;
    mainProgram = "dgx-machine";
    platforms = lib.platforms.linux;
  };
}
