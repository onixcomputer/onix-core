# Development environment: formatter, pre-commit, MCP servers, devShells.
#
# Wrapper must declare args so adios-flake detects system dependency.
# The @-pattern captures the full set for pass-through to the inner module.
{
  pkgs,
  lib,
  self,
  self',
  inputs',
  ...
}:
(import ../parts/dev-env.nix) {
  inherit
    pkgs
    lib
    self
    self'
    inputs'
    ;
}
