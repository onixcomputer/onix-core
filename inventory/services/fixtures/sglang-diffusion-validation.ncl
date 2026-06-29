let sc = import "../settings-contracts.ncl" in
let default_port = 30000 in
let default_gpu_count = 1 in
{
  positive =
    sc.validate_fields
      "sglang-diffusion:default"
      "sglang-diffusion-positive"
      {
        stateDir = "/var/lib/sglang-diffusion",
        image = "lmsysorg/sglang:dev",
        host = "127.0.0.1",
        port = default_port,
        modelPath = "krea/Krea-2-Turbo",
        numGpus = default_gpu_count,
        gpuPassthrough = "nixos-nvidia",
        sharedMemorySize = "32g",
        installDiffusionDependencies = true,
        environmentFiles = [],
        conflictingUnits = ["llamacpp-server-vibethinker-britton-desktop.service"],
        extraArgs = ["--dit-layerwise-offload"],
        extraContainerOptions = [],
      },
  negative =
    sc.validate_fields
      "sglang-diffusion:default"
      "sglang-diffusion-negative"
      {
        port = "not-a-port",
        numGpus = "one",
        gpuPassthrough = "invalid-mode",
        environmentFiles = [1],
      },
}
