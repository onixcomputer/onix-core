_: {
  instances = {
    "ollama" = {
      module.name = "ollama";
      module.input = "self";
      roles.default.machines.aspen1.settings = {
        models = [ "qwen3:4b" ];
      };
    };
  };
}
