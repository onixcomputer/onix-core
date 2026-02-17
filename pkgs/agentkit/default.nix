{
  lib,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "agentkit";
  version = "0.1.0";

  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;

  meta = with lib; {
    description = "Universal AI agent instruction format and management tool";
    homepage = "https://github.com/brittonr/onix-core";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "agentkit";
  };
}
