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
          # Use ollama as the default service
          serviceType = "ollama";

          # Default ollama port
          port = 11434;
          host = "0.0.0.0";

          # Enable GPU acceleration
          enableGPU = true;

          # Default models to download
          models = [
            "llama3.2:3b"
            "codellama:7b"
          ];
        };
      };

      # LLM client on machines with 'llm-client' tag
      roles.client = {
        tags."llm-client" = { };
        settings = {
          # Install ollama client tools
          clientType = "ollama";

          # No default server specified - clients will need to configure manually
          # or use service discovery in the future
          defaultServer = null;

          # Additional useful packages for LLM work
          extraPackages = [
            "curl"
            "jq"
          ];
        };
      };
    };
  };
}
