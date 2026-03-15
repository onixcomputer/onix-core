# NixOS VM integration tests.
#
# Each test boots QEMU VMs and exercises real service configurations.
# Runs on Linux only (VMs need KVM). The aarch64-linux builder (macOS
# linux-builder VM) has KVM via Virtualization.framework and the
# nixos-test feature enabled in britton-air's config.
{ pkgs, lib, ... }:
let
  vmTests = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
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
