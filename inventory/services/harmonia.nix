_: {
  instances = {
    harmonia = {
      module.name = "harmonia";
      module.input = "self";
      roles.server = {
        machines."aspen2" = { };
        settings = {
          port = 5000;
          priority = 30;
        };
      };
    };
  };
}
