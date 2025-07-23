{ inputs, ... }:
let
  machines = import ./machines.nix { inherit inputs; };
  users = import ./users.nix { inherit inputs; };

  instances = {
    roster = {
      module.name = "roster";
      roles.default.tags.all = { };
      roles.default.settings = {
        inherit users;
        homeProfilesPath = ../home-profiles;
      };
    };
  };
in
{
  inherit (machines) machines;
  inherit instances;
}
