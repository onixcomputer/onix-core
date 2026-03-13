_: {
  instances = {
    # LLM service setup
    "llm" = {
      module.name = "llm";
      module.input = "self";

      # LLM server on machines with 'llm' tag
      roles.server = {
        tags."llm" = { };
        settings = {
          serviceType = "ollama";
          port = 11434;
          host = "0.0.0.0";
          enableGPU = true;
          models = [
            "qwen3.5:9b" # Local fast model for britton-desktop (NVIDIA)
          ];
          model = null;
        };
      };

      # LLM client on machines with 'llm-client' tag
      roles.client = {
        tags."llm-client" = { };
        settings = {
          clientType = "ollama";
          extraPackages = [
            "curl"
            "jq"
          ];
        };
      };
    };
  };
}
