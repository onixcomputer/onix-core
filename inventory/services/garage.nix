_: {
  instances = {
    storage = {
      module.name = "garage";
      module.input = "clan-core";
      roles.default = {
        machines.aspen1 = { };
      };
    };
  };
}
