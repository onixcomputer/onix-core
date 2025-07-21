{ inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;

  # Import modules
  core = import ./core { inherit inputs; };
  services = import ./services { inherit inputs; };
  tags = import ./tags { inherit inputs; };
  homeProfiles = import ./home-profiles { inherit inputs; };

  inventory = {
    inherit (core) machines;
    instances = lib.recursiveUpdate (lib.recursiveUpdate (lib.recursiveUpdate core.instances services.instances) tags.instances) homeProfiles.instances;
  };
in
inventory
