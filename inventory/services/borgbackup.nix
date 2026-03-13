_: {
  instances = {
    borgbackup = {
      module.name = "borgbackup";
      module.input = "clan-core";
      roles = {
        server = {
          machines.aspen1 = { };
          settings = {
            directory = "/var/lib/borg";
          };
        };
        client = {
          tags.backup = { };
          extraModules = [ ../../modules/borgbackup-extras.nix ];
        };
      };
    };
  };
}
