{
  server = {
    serviceType = { type = "enum", values = ["ollama", "vllm", "llamacpp", "openai-compatible"], default = "ollama", description = "Type of LLM service to run" },
    port = { type = "port", default = 11434, description = "Port for the LLM service" },
    host = { type = "string", default = "0.0.0.0", description = "Host address to bind to" },
    models = { type = "array_string", default = [], description = "List of models to download and serve" },
    model = { type = "nullable_string", default = null, description = "Primary model to serve (vllm)" },
    enableGPU = { type = "bool", default = true, description = "Enable GPU acceleration" },
    containerImage = { type = "nullable_string", default = null, description = "Custom container image for vLLM" },
    extraEnv = { type = "record", default = {}, description = "Extra environment variables for vLLM container" },
    autoStart = { type = "bool", default = true, description = "Start service automatically on boot" },
  },
  client = {
    clientType = { type = "enum", values = ["ollama", "vllm", "openai", "curl"], default = "ollama", description = "Type of client tools to install" },
    defaultServer = { type = "nullable_string", default = null, description = "Default LLM server endpoint" },
    extraPackages = { type = "array_string", default = [], description = "Additional packages to install" },
  },
}
