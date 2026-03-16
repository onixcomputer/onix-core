# Build all machine configurations as nix flake checks.
# Catches eval/build failures in CI without deploying.
#
# Also validates that machinesPerSystem stays in sync with the
# actual machine inventory — fails if a machine is added to
# inventory but not listed here (or vice versa).
{
  self,
  lib,
  pkgs,
  system,
  ...
}:
let
  machinesPerSystem = {
    x86_64-linux = [
      "aspen1"
      "aspen2"
      "bonsai"
      "britton-desktop"
      "britton-fw"
    ];
    aarch64-linux = [
      "pine"
      "utm-vm"
    ];
    aarch64-darwin = [
      "britton-air"
    ];
  };

  listedMachines = lib.sort lib.lessThan (lib.concatLists (lib.attrValues machinesPerSystem));
  actualMachines = lib.sort lib.lessThan (
    lib.attrNames (import ../inventory/core/machines.nix { }).machines
  );

  syncCheck = pkgs.runCommand "machines-per-system-check" { } ''
    ${lib.optionalString (listedMachines != actualMachines) ''
      echo "machinesPerSystem out of sync with inventory/core/machines.nix:"
      echo "  listed: ${lib.concatStringsSep " " listedMachines}"
      echo "  actual: ${lib.concatStringsSep " " actualMachines}"
      exit 1
    ''}
    touch $out
  '';

  nixosMachines = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux (
    lib.mapAttrs' (n: lib.nameValuePair "nixos-${n}") (
      lib.genAttrs (machinesPerSystem.${system} or [ ]) (
        name: self.nixosConfigurations.${name}.config.system.build.toplevel
      )
    )
  );

  darwinMachines = lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin (
    lib.mapAttrs' (n: lib.nameValuePair "darwin-${n}") (
      lib.genAttrs (machinesPerSystem.${system} or [ ]) (
        name: self.darwinConfigurations.${name}.config.system.build.toplevel
      )
    )
  );
in
{
  checks = {
    machines-per-system-sync = syncCheck;
  }
  // nixosMachines
  // darwinMachines;
}
