# Build all machine configurations as nix flake checks.
# Catches eval/build failures in CI without deploying.
# Inspired by Mic92/dotfiles checks/flake-module.nix
{
  self,
  lib,
  system,
  ...
}:
let
  # Map machine architectures to their system strings
  machinesPerSystem = {
    x86_64-linux = [
      "britton-fw"
      "britton-gpd"
      "bonsai"
      "aspen1"
      "aspen2"
      "britton-desktop"
    ];
    aarch64-linux = [
      "pine"
      # utm-vm: needs `clan vars generate --machine utm-vm` before it can eval
    ];
    # aarch64-darwin = [ "britton-air" ];
  };

  nixosMachines = lib.mapAttrs' (n: lib.nameValuePair "nixos-${n}") (
    lib.genAttrs (machinesPerSystem.${system} or [ ]) (
      name: self.nixosConfigurations.${name}.config.system.build.toplevel
    )
  );
in
{
  checks = nixosMachines;
}
