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
  sshHostKeyChecks = (import ./_ssh-host-key-checks.nix) innerArgs;
  varsChecks = (import ./_vars-checks.nix) innerArgs;
  vmTests = (import ./_vm-tests.nix) { inherit pkgs lib; };
  wasmChecks = (import ./_wasm-checks.nix) innerArgs;
  tagChecks = (import ./_tag-checks.nix) innerArgs;
  moduleChecks = (import ./_module-checks.nix) innerArgs;
  builderChecks = (import ./_builder-checks.nix) innerArgs;
  colorChecks = (import ./_color-checks.nix) { inherit self pkgs; };
  grafanaChecks = (import ./_grafana-checks.nix) innerArgs;
  helixChecks = (import ./_helix-checks.nix) innerArgs;
  homeManagerChecks = (import ./_home-manager-checks.nix) innerArgs;
  kacheNixRustChecks = (import ./_kache-nix-rust-checks.nix) innerArgs;
  meshLlmChecks = (import ./_mesh-llm-checks.nix) innerArgs;
  personalRadicleNodeChecks = (import ./_personal-radicle-node-checks.nix) innerArgs;
  radicleCiRunnerChecks = (import ./_radicle-ci-runner-checks.nix) innerArgs;
  radicleChoregraphAdmissionChecks = (import ./_radicle-choregraph-admission-checks.nix) innerArgs;
  radicleDurableFilePublicationAdmissionChecks = (import ./_radicle-durable-file-publication-admission-checks.nix) innerArgs;
  radicleExecutionGraphAdmissionChecks = (import ./_radicle-execution-graph-admission-checks.nix) innerArgs;
  radicleNodeChecks = (import ./_radicle-node-checks.nix) innerArgs;
  radiclePrivatePilotChecks = (import ./_radicle-private-pilot-checks.nix) innerArgs;
  radicleSeedReplicaChecks = (import ./_radicle-seed-replica-checks.nix) innerArgs;
  radicleSourceAdmissionChecks = (import ./_radicle-source-admission-checks.nix) innerArgs;

  packageChecks = lib.mapAttrs' (n: lib.nameValuePair "package-${n}") self'.packages;
  devShellChecks = lib.mapAttrs' (n: lib.nameValuePair "devShell-${n}") self'.devShells;
in
{
  checks =
    (machineChecks.checks or { })
    // (sshHostKeyChecks.checks or { })
    // (varsChecks.checks or { })
    // (vmTests.checks or { })
    // (wasmChecks.checks or { })
    // (tagChecks.checks or { })
    // (moduleChecks.checks or { })
    // builderChecks
    // colorChecks.checks
    // (grafanaChecks.checks or { })
    // (helixChecks.checks or { })
    // (homeManagerChecks.checks or { })
    // (kacheNixRustChecks.checks or { })
    // (meshLlmChecks.checks or { })
    // (personalRadicleNodeChecks.checks or { })
    // (radicleCiRunnerChecks.checks or { })
    // (radicleChoregraphAdmissionChecks.checks or { })
    // (radicleDurableFilePublicationAdmissionChecks.checks or { })
    // (radicleExecutionGraphAdmissionChecks.checks or { })
    // (radicleNodeChecks.checks or { })
    // (radiclePrivatePilotChecks.checks or { })
    // (radicleSeedReplicaChecks.checks or { })
    // (radicleSourceAdmissionChecks.checks or { })
    // packageChecks
    // devShellChecks;
}
