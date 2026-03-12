{ inputs, ... }:
let
  machines = import ./machines.nix { inherit inputs; };
  users = import ./users.nix { inherit inputs; };
in
{
  inherit (machines) machines;
  inherit (users) instances;
}
