{
  default = {
    host = { type = "string", default = "127.0.0.1", description = "Host address to bind to" },
    port = { type = "port", default = 11434, description = "Port for the Ollama API" },
    models = { type = "array_string", default = [], description = "List of models to pre-pull on activation" },
    enableGPU = { type = "bool", default = true, description = "Enable GPU acceleration" },
    acceleration = { type = "enum", values = ["rocm", "cuda", "vulkan", "cpu"], default = "rocm", description = "Acceleration backend" },
  },
}
