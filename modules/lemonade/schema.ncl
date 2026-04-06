{
  default = {
    host = { type = "string", default = "0.0.0.0", description = "Address to bind for connections" },
    port = { type = "port", default = 13305, description = "Port for the Lemonade OpenAI-compatible API" },
    backend = { type = "enum", values = ["auto", "rocm", "vulkan", "cpu", "system"], default = "rocm", description = "llama.cpp backend to use" },
    models = { type = "array_string", default = [], description = "Models to pull on activation (HuggingFace model names)" },
    contextSize = { type = "number", default = 8192, description = "Context size for llama.cpp" },
    maxLoadedModels = { type = "number", default = 1, description = "Maximum number of models loaded simultaneously" },
    customModels = { type = "record", default = {}, description = "Custom HuggingFace models to register (name -> {checkpoint, recipe?, size?})" },
    extraArgs = { type = "string", default = "", description = "Extra arguments passed to llama.cpp backend" },
    offline = { type = "bool", default = false, description = "Disable model downloads (serve only pre-cached models)" },
  },
}
