_: {
  instances = {
    "clonadic" = {
      module.name = "clonadic";
      module.input = "self";
      roles.default.machines.aspen1.settings = {
        model = "qwen3:4b";
      };
    };
  };
}
