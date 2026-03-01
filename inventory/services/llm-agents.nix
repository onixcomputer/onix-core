_: {
  instances = {
    "llm-agents" = {
      module.name = "llm-agents";
      module.input = "self";
      roles.default.tags.llm-client = { };
      roles.default.settings = {
        packages = [
          "pi"
          "openspec"
        ];
      };
    };
  };
}
