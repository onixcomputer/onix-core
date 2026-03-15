_: {
  instances = {

    matrix-synapse = {
      module.name = "matrix-synapse";
      module.input = "clan-core";
      roles.default = {
        extraModules = [ ../../modules/matrix-synapse-cf ];
        machines.aspen1 = {
          settings = {
            server_tld = "onix.computer";
            app_domain = "matrix.onix.computer";
            acmeEmail = "admin@onix.computer";
            users.brittonr.admin = true;
          };
        };
      };
    };

  };
}
