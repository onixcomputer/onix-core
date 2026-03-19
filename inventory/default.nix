{ inputs, self, ... }:
let
  inherit (inputs.nixpkgs) lib;

  # Import modules
  core = import ./core { inherit inputs self; };
  services = import ./services { inherit inputs self; };
  tags = import ./tags { inherit inputs; };

  inventory = {
    inherit (core) machines;
    instances = lib.recursiveUpdate (lib.recursiveUpdate core.instances services.instances) tags.instances;
  };
in
inventory
