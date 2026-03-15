# NixOS VM integration tests.
#
# Each test boots QEMU VMs and exercises real service configurations.
# Restricted to x86_64-linux: the aarch64-linux builder (macOS linux-builder VM)
# lacks KVM and the nixos-test feature required to run QEMU VM tests.
{ pkgs, lib, ... }:
let
  isX86Linux = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  vmTests = lib.optionalAttrs isX86Linux {
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
