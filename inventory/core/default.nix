{ inputs, ... }:
let
  machines = import ./machines.nix { inherit inputs; };
  roster = import ./roster.nix { inherit inputs; };

in
{
  inherit (machines) machines;
  inherit (roster) instances;
}
