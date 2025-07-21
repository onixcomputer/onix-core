{ inputs, ... }:
let
  machines = import ./machines.nix { inherit inputs; };
  users = import ./users.nix { inherit inputs; };

  instances = {
    user-assignments = {
      module.name = "user-assignments";
      roles.default.tags.all = { };
      roles.default.settings = {
        inherit users;
      };
    };
  };
in
{
  inherit (machines) machines;
  inherit instances;
}
