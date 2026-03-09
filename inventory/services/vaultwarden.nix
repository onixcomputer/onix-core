_: {
  instances = {

    "brittonr-vault" = {
      module.name = "vaultwarden";
      module.input = "self";
      roles.server = {
        machines.aspen1 = { };
      };
    };

  };
}
