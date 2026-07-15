{
  default = {
    stateDir = { type = "string", default = "/var/lib/tt-inference-server", description = "Persistent host directory for model weights, TT caches, and logs" },
    image = { type = "string", default = "ghcr.io/tenstorrent/tt-inference-server/vllm-tt-metal-src-release-ubuntu-22.04-amd64:0.18.0-c49bb76-6b4a3a7@sha256:6aee48978be401c0a86cb1761c4d64af818df8380bc7b27c1018d704518545ff", description = "Digest-pinned Tenstorrent inference-server OCI image" },
    model = { type = "string", default = "meta-llama/Llama-3.1-8B-Instruct", description = "Exact Hugging Face model repository resolved by the bundled model catalog" },
    device = { type = "enum", values = ["p150"], default = "p150", description = "Tenstorrent hardware profile passed with --tt-device" },
    physicalDeviceId = { type = "number", default = 0, description = "Physical /dev/tenstorrent device node exposed exclusively to the container" },
    host = { type = "string", default = "127.0.0.1", description = "Loopback address published for the OpenAI-compatible API" },
    port = { type = "port", default = 8000, description = "Host and container API port" },
    cacheUid = { type = "number", default = 1000, description = "Container UID that owns the persistent cache" },
    cacheGid = { type = "number", default = 1000, description = "Container GID that owns the persistent cache" },
    enableTraceCapture = { type = "bool", default = true, description = "Allow the image entrypoint to run its model-specific trace-capture warmup" },
    autoStart = { type = "bool", default = true, description = "Start the container automatically when its credential and device are available" },
    extraArgs = { type = "array_string", default = [], description = "Additional vLLM arguments passed through the image entrypoint" },
  },
}
