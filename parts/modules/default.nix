# Custom flake-parts modules for onix-core
# These modules define transposed outputs for better tooling organization
{ ... }:
{
  imports = [
    ./analysis-tools.nix
    ./clan-tools.nix
  ];
}
