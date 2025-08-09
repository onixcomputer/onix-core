{ inputs, ... }:
let
  machines = import ./machines.nix { inherit inputs; };
  roster = import ./roster.nix { inherit inputs; };

  instances = {
    roster = {
      module.name = "roster";
      roles.default.tags.all = { };
      roles.default.settings = {
        users = roster;
        homeProfilesPath = ../home-profiles;
      };
    };
  };
in
{
  inherit (machines) machines;
  inherit instances;
}
