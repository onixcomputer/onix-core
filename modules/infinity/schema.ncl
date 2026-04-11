{
  default = {
    stateDir = { type = "string", default = "/var/lib/infinity", description = "Persistent state directory for Infinity cache data" },
    image = { type = "string", default = "michaelf34/infinity:0.0.77-cpu@sha256:94db836145f609c508f3f296f3b9bd0e78ae088025e879664d073dfd9f929e96", description = "OCI image for the Infinity embeddings server" },
    host = { type = "string", default = "127.0.0.1", description = "Host address Infinity binds to" },
    port = { type = "port", default = 7997, description = "Port for the Infinity OpenAI-compatible embeddings API" },
    modelId = { type = "string", default = "BAAI/bge-m3", description = "Hugging Face model ID to serve" },
    servedModelName = { type = "string", default = "bge-m3", description = "Model name exposed via the OpenAI-compatible API" },
    enableGPU = { type = "bool", default = false, description = "Expose NVIDIA GPUs to the container with --gpus=all" },
    engine = { type = "string", default = "optimum", description = "Infinity engine argument, e.g. optimum or torch" },
    device = { type = "string", default = "auto", description = "Infinity device argument, e.g. cuda, cpu, or auto" },
    extraArgs = { type = "array_string", default = [], description = "Extra CLI arguments passed to infinity_emb v2" },
  },
}
