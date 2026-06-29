let default_port = 30000 in
let default_gpu_count = 1 in
{
  default = {
    stateDir = { type = "string", default = "/var/lib/sglang-diffusion", description = "Persistent state directory for SGLang-Diffusion cache data" },
    image = { type = "string", default = "lmsysorg/sglang:dev", description = "OCI image for the SGLang-Diffusion server" },
    host = { type = "string", default = "127.0.0.1", description = "Host address SGLang binds to" },
    port = { type = "port", default = default_port, description = "Port for the SGLang OpenAI-compatible images API" },
    modelPath = { type = "string", default = "krea/Krea-2-Turbo", description = "Hugging Face model path to serve" },
    numGpus = { type = "number", default = default_gpu_count, description = "Number of GPUs passed to sglang serve" },
    gpuPassthrough = { type = "enum", values = ["none", "docker-gpus", "nixos-nvidia"], default = "none", description = "Container GPU passthrough strategy. nixos-nvidia manually exposes /dev/nvidia0 plus NixOS driver libraries and avoids Docker --gpus=all." },
    sharedMemorySize = { type = "string", default = "32g", description = "Docker shared-memory size passed with --shm-size" },
    installDiffusionDependencies = { type = "bool", default = true, description = "Install SGLang diffusion extras in the container before starting the server" },
    environmentFiles = { type = "array_string", default = [], description = "Environment files passed to the container, useful for HF_TOKEN" },
    conflictingUnits = { type = "array_string", default = [], description = "Systemd units that must be stopped while this image service is running" },
    extraArgs = { type = "array_string", default = [], description = "Extra CLI arguments appended to sglang serve" },
    extraContainerOptions = { type = "array_string", default = [], description = "Extra Docker options appended to the generated container options" },
  },
}
