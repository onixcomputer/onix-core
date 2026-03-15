# Flake checks: machine builds, vars/secrets validation, packages, devShells, VM tests.
#
# Composes parts/machine-checks.nix, parts/vars-checks.nix, and
# parts/vm-tests.nix, then adds package-* and devShell-* checks
# so buildbot verifies everything.
{
  self,
  self',
  inputs',
  pkgs,
  lib,
  system,
  ...
}:
let
  innerArgs = {
    inherit
      self
      self'
      inputs'
      pkgs
      lib
      system
      ;
  };
  machineChecks = (import ../parts/machine-checks.nix) innerArgs;
  varsChecks = (import ../parts/vars-checks.nix) innerArgs;
  vmTests = (import ../parts/vm-tests.nix) { inherit pkgs lib; };

  packageChecks = lib.mapAttrs' (n: lib.nameValuePair "package-${n}") self'.packages;
  devShellChecks = lib.mapAttrs' (n: lib.nameValuePair "devShell-${n}") self'.devShells;
in
{
  checks =
    (machineChecks.checks or { })
    // (varsChecks.checks or { })
    // (vmTests.checks or { })
    // packageChecks
    // devShellChecks;
}
