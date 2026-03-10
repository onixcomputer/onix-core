_: {
  instances = {
    "ollama" = {
      module.name = "ollama";
      module.input = "self";
      roles.default.machines.aspen1.settings = {
        host = "0.0.0.0";
        models = [ "qwen3.5:122b" ];
      };
    };
  };
}
