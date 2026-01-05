# Development-only inputs for onix-core
# These inputs are only fetched when evaluating dev outputs (devShells, checks, formatter)
# This improves laziness - building nixosConfigurations won't fetch these
{
  inputs = {
    treefmt-nix.url = "github:numtide/treefmt-nix";
    pre-commit-hooks-nix.url = "github:cachix/pre-commit-hooks.nix";
  };

  # This flake exists only to provide inputs to the dev partition
  # nixpkgs follows is handled at the partition level, not here
  outputs = _: { };
}
