# Flake checks: machine builds, vars/secrets validation, packages, devShells, VM tests.
#
# Composes _machine-checks.nix, _vars-checks.nix, and
# _vm-tests.nix, then adds package-* and devShell-* checks
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
  machineChecks = (import ./_machine-checks.nix) innerArgs;
  varsChecks = (import ./_vars-checks.nix) innerArgs;
  vmTests = (import ./_vm-tests.nix) { inherit pkgs lib; };
  wasmChecks = (import ./_wasm-checks.nix) innerArgs;
  tagChecks = (import ./_tag-checks.nix) innerArgs;
  moduleChecks = (import ./_module-checks.nix) innerArgs;
  builderChecks = (import ./_builder-checks.nix) innerArgs;
  colorChecks = (import ./_color-checks.nix) { inherit pkgs; };

  packageChecks = lib.mapAttrs' (n: lib.nameValuePair "package-${n}") self'.packages;
  devShellChecks = lib.mapAttrs' (n: lib.nameValuePair "devShell-${n}") self'.devShells;
in
{
  checks =
    (machineChecks.checks or { })
    // (varsChecks.checks or { })
    // (vmTests.checks or { })
    // (wasmChecks.checks or { })
    // (tagChecks.checks or { })
    // (moduleChecks.checks or { })
    // builderChecks
    // colorChecks.checks
    // packageChecks
    // devShellChecks;
}
