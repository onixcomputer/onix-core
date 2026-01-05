# Development partition module for onix-core
# This module is only evaluated for dev outputs (devShells, checks, formatter)
{ inputs, ... }:
{
  imports = [
    # External flake modules
    inputs.treefmt-nix.flakeModule
    inputs.pre-commit-hooks-nix.flakeModule

    # Custom transposed modules for organized outputs
    ../parts/modules

    # Development tooling
    ../parts/formatter.nix
    ../parts/pre-commit.nix
    ../parts/devshells.nix
    ../parts/checks.nix
    ../parts/vm-checks.nix

    # Analysis and infrastructure tools
    ../parts/sops-viz.nix
    ../parts/cloud-cli.nix
  ];
}
