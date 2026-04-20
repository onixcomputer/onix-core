{
  default = {
    host = { type = "string", default = "0.0.0.0", description = "Address to bind for connections" },
    port = { type = "port", default = 13305, description = "Port for the Lemonade OpenAI-compatible API" },
    backend = { type = "enum", values = ["auto", "rocm", "vulkan", "cpu", "system"], default = "rocm", description = "llama.cpp backend to use" },
    models = { type = "array_string", default = [], description = "Models to pull on activation (HuggingFace model names)" },
    contextSize = { type = "number", default = 8192, description = "Context size for llama.cpp" },
    maxLoadedModels = { type = "number", default = 1, description = "Maximum number of models loaded simultaneously" },
    customModels = { type = "record", default = {}, description = "Custom HuggingFace models to register (name -> {checkpoint, recipe?, size?})" },
    globalTimeout = { type = "number", default = 300, description = "Global timeout in seconds for HTTP, inference, and readiness checks (0 = infinite)" },
    extraArgs = { type = "string", default = "", description = "Extra arguments passed to llama.cpp backend" },
    offline = { type = "bool", default = false, description = "Disable model downloads (serve only pre-cached models)" },
    healthCheckInterval = { type = "number", default = 10, description = "Seconds between backend health checks (0 = disable health monitoring)" },
    healthCheckThreshold = { type = "number", default = 3, description = "Consecutive missed checks before restarting (grace = interval * threshold)" },
    healthCheckGrace = { type = "number", default = 120, description = "Seconds after start before health monitoring begins (model loading time)" },
  },
}
