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
          # Use ollama as the default service (can also be "vllm")
          serviceType = "ollama";

          # Default port (11434 for ollama, 8000 for vllm)
          port = 11434;
          host = "0.0.0.0";

          # Enable GPU acceleration
          enableGPU = true;

          # Default models to download (ollama) or model path (vllm)
          models = [
            "llama3.2:3b"
            "codellama:7b"
          ];

          # For vLLM, specify model path like:
          # model = "microsoft/DialoGPT-medium";
          # model = "/path/to/local/model";
          model = null;
        };
      };

      # LLM client on machines with 'llm-client' tag
      roles.client = {
        tags."llm-client" = { };
        settings = {
          # Install client tools (can be "ollama", "vllm", "openai", or "curl")
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
