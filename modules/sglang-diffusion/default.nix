{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };

  minimumGpuCount = 1;
  singleGpuCount = 1;
  defaultCudaDevice = "0";
  stateDirectoryMode = "0755";
  driverLibraryPath = "/run/opengl-driver/lib:/usr/local/cuda/lib64";

  mkServeArgs =
    {
      modelPath,
      host,
      port,
      numGpus,
      extraArgs,
    }:
    [
      "sglang"
      "serve"
      "--model-path"
      modelPath
      "--host"
      host
      "--port"
      (toString port)
      "--num-gpus"
      (toString numGpus)
    ]
    ++ extraArgs;

  mkInstallCommand = installDiffusionDependencies: ''
    if ${if installDiffusionDependencies then "true" else "false"}; then
      if [ -d /sglang/python ]; then
        cd /sglang
        if command -v uv >/dev/null 2>&1; then
          uv pip install -e "python[diffusion]" --system --break-system-packages --prerelease=allow
        else
          pip install -e "python[diffusion]" --break-system-packages
        fi
      else
        if command -v uv >/dev/null 2>&1; then
          uv pip install "sglang[diffusion]" --system --break-system-packages --prerelease=allow
        else
          pip install --pre "sglang[diffusion]" --break-system-packages
        fi
      fi
    fi
  '';
in
{
  _class = "clan.service";

  manifest = {
    name = "sglang-diffusion";
    readme = "SGLang-Diffusion OpenAI-compatible image generation server";
    description = "Local text-to-image inference with SGLang-Diffusion";
    categories = [
      "AI/ML"
      "Inference"
      "Images"
    ];
  };

  roles.default = {
    description = "SGLang-Diffusion server";
    interface = mkSettings.mkInterface schema.default;

    perInstance =
      { instanceName, extendSettings, ... }:
      {
        nixosModule =
          { config, lib, ... }:
          let
            ms = import ../../lib/mk-settings.nix { inherit lib; };
            settings = extendSettings (ms.mkDefaults schema.default);

            inherit (settings)
              stateDir
              image
              host
              port
              modelPath
              numGpus
              gpuPassthrough
              sharedMemorySize
              installDiffusionDependencies
              environmentFiles
              conflictingUnits
              extraArgs
              extraContainerOptions
              ;

            containerName = "sglang-diffusion-${instanceName}";
            cacheDir = "${stateDir}/huggingface";
            localOnlyHosts = [
              "127.0.0.1"
              "::1"
            ];

            nvidiaDeviceOptions = [
              "--device=/dev/nvidiactl"
              "--device=/dev/nvidia-uvm"
              "--device=/dev/nvidia-uvm-tools"
              "--device=/dev/nvidia${defaultCudaDevice}"
            ];
            nvidiaDriverPackage = config.hardware.nvidia.package;
            nvidiaDriverVolumes = [
              "/run/opengl-driver:/run/opengl-driver:ro"
              "/run/opengl-driver-32:/run/opengl-driver-32:ro"
              "${nvidiaDriverPackage}:${nvidiaDriverPackage}:ro"
            ];
            gpuOptions =
              if gpuPassthrough == "docker-gpus" then
                [ "--gpus=all" ]
              else if gpuPassthrough == "nixos-nvidia" then
                nvidiaDeviceOptions
              else
                [ ];
            gpuVolumes = if gpuPassthrough == "nixos-nvidia" then nvidiaDriverVolumes else [ ];
            gpuEnvironment = lib.optionalAttrs (gpuPassthrough == "nixos-nvidia") {
              CUDA_VISIBLE_DEVICES = defaultCudaDevice;
              LD_LIBRARY_PATH = driverLibraryPath;
              NVIDIA_DRIVER_CAPABILITIES = "compute,utility";
              NVIDIA_VISIBLE_DEVICES = defaultCudaDevice;
            };

            serveArgs = mkServeArgs {
              inherit
                modelPath
                host
                port
                numGpus
                extraArgs
                ;
            };
            startupScript = ''
              set -euo pipefail
              ${mkInstallCommand installDiffusionDependencies}
              exec ${lib.escapeShellArgs serveArgs}
            '';
          in
          {
            assertions = [
              {
                assertion = modelPath != "";
                message = "sglang-diffusion ${instanceName}: modelPath must not be empty";
              }
              {
                assertion = host != "";
                message = "sglang-diffusion ${instanceName}: host must not be empty";
              }
              {
                assertion = numGpus >= minimumGpuCount;
                message = "sglang-diffusion ${instanceName}: numGpus must be positive";
              }
              {
                assertion = sharedMemorySize != "";
                message = "sglang-diffusion ${instanceName}: sharedMemorySize must not be empty";
              }
              {
                assertion = !(gpuPassthrough == "nixos-nvidia" && numGpus != singleGpuCount);
                message = "sglang-diffusion ${instanceName}: nixos-nvidia passthrough exposes one GPU; use docker-gpus or extraContainerOptions for multi-GPU";
              }
            ];

            networking.firewall.allowedTCPPorts = lib.optionals (!(lib.elem host localOnlyHosts)) [ port ];

            systemd.tmpfiles.rules = [
              "d ${stateDir} ${stateDirectoryMode} root root -"
              "d ${cacheDir} ${stateDirectoryMode} root root -"
            ];

            systemd.services."docker-${containerName}" = {
              conflicts = conflictingUnits;
              before = conflictingUnits;
              preStart = ''
                install -d -m ${stateDirectoryMode} ${stateDir}
                install -d -m ${stateDirectoryMode} ${cacheDir}
              '';
            };

            virtualisation.oci-containers = {
              backend = "docker";
              containers."${containerName}" = {
                inherit image environmentFiles;
                pull = "always";
                extraOptions = [
                  "--network=host"
                  "--ipc=host"
                  "--shm-size=${sharedMemorySize}"
                ]
                ++ gpuOptions
                ++ extraContainerOptions;
                environment = {
                  HF_HOME = "/root/.cache/huggingface";
                  PYTORCH_CUDA_ALLOC_CONF = "expandable_segments:True";
                }
                // gpuEnvironment;
                cmd = [
                  "zsh"
                  "-lc"
                  startupScript
                ];
                volumes = [ "${cacheDir}:/root/.cache/huggingface" ] ++ gpuVolumes;
              };
            };
          };
      };
  };
}
