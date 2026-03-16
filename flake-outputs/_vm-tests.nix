# NixOS VM integration tests.
#
# Each test boots QEMU VMs and exercises real service configurations.
# Restricted to x86_64-linux where bare-metal builders (aspen1/aspen2)
# have KVM. The aarch64-linux builder is macOS's linux-builder VM,
# which can't do nested KVM — QEMU falls back to TCG and tests timeout.
{ pkgs, lib, ... }:
let
  # VM tests need KVM for reasonable performance. Only emit them for
  # systems where we have bare-metal builders with /dev/kvm.
  # aarch64-linux builds go to macOS's linux-builder VM, which has no
  # nested KVM — tests fall back to TCG and timeout.
  vmTests = lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
    vm-static-server = import ../tests/static-server.nix { inherit pkgs; };
    vm-prometheus = import ../tests/prometheus.nix { inherit pkgs; };
    vm-loki = import ../tests/loki.nix { inherit pkgs; };
    vm-harmonia = import ../tests/harmonia.nix { inherit pkgs; };
    vm-monitoring-stack = import ../tests/monitoring-stack.nix { inherit pkgs; };
  };
in
{
  checks = vmTests;
}
