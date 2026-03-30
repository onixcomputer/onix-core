{
  worker = {
    bindAddress = { type = "string", default = "0.0.0.0", description = "Address to bind the RPC worker" },
    port = { type = "port", default = 50052, description = "RPC worker port" },
    enableCache = { type = "bool", default = true, description = "Enable worker-side KV cache" },
  },
  server = {
    host = { type = "string", default = "0.0.0.0", description = "Server bind address" },
    port = { type = "port", default = 8081, description = "HTTP API port" },
    model = { type = "nullable_record", default = null, description = "Model repo/file specification" },
    rpcWorkers = { type = "array_string", default = [], description = "RPC worker addresses (host:port)" },
    gpuLayers = { type = "number", default = 999, description = "Number of layers to offload to GPU" },
    flashAttention = { type = "bool", default = true, description = "Enable flash attention" },
    contextSize = { type = "number", default = 8192, description = "Context window size" },
    noMmap = { type = "bool", default = true, description = "Disable mmap for model loading" },
    extraArgs = { type = "array_string", default = [], description = "Extra llama-server arguments" },
  },
}
