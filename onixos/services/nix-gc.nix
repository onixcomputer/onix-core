# nix-gc.ncl sets services.fast-nix-gc and services.fast-nix-optimise.
{ inputs, ... }:
{
  nixosModules = [ inputs.fast-nix-gc.nixosModules.default ];
}
