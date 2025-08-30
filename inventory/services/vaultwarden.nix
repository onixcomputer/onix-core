_: {
  instances = {

    "adeci-vault" = {
      module.name = "vaultwarden";
      module.input = "self";
      roles.server = {
        machines.sequoia = { };
      };
    };

    "brittonr-vault" = {
      module.name = "vaultwarden";
      module.input = "self";
      roles.server = {
        machines.aspen1 = { };
      };
    };

  };
}
