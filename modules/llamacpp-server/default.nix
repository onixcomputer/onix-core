{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";

  manifest = {
    name = "llamacpp-server";
    readme = "Direct llama.cpp OpenAI-compatible inference server";
    description = "Runs llama-server directly with a selected Nix-built llama.cpp backend";
    categories = [
      "AI/ML"
      "Inference"
    ];
  };

  roles.server = {
    description = "Direct llama.cpp server that exposes an OpenAI-compatible API";
    interface = mkSettings.mkInterface schema.server;

    perInstance =
      { instanceName, extendSettings, ... }:
      {
        nixosModule =
          {
            pkgs,
            lib,
            ...
          }:
          let
            ms = import ../../lib/mk-settings.nix { inherit lib; };
            cfg = extendSettings (ms.mkDefaults schema.server);

            inherit (cfg)
              host
              port
              backend
              modelRepo
              modelFile
              modelRevision
              modelAlias
              gpuLayers
              contextSize
              batchSize
              ubatchSize
              parallelSlots
              cacheTypeK
              cacheTypeV
              flashAttention
              noMmap
              enableMetrics
              autoStart
              extraArgs
              ;

            serviceName = "llamacpp-server-${instanceName}";
            pullServiceName = "${serviceName}-model-pull";
            stateDirectory = serviceName;
            stateDir = "/var/lib/${stateDirectory}";
            modelsDir = "${stateDir}/models";
            modelPath = "${modelsDir}/${modelFile}";
            modelUrl = "https://huggingface.co/${modelRepo}/resolve/${modelRevision}/${modelFile}";

            stateDirectoryMode = "0755";
            modelFileMode = "0644";
            partialSuffix = ".partial";
            pullRestartDelay = "60s";
            serverRestartDelay = "10s";
            infiniteTimeout = "infinity";
            curlRetryCount = 5;
            curlRetryDelaySeconds = 10;
            disabledNumericOption = 0;
            cudaGpuLayerCount = gpuLayers;
            cpuGpuLayerCount = 0;
            effectiveGpuLayers = if backend == "cpu" then cpuGpuLayerCount else cudaGpuLayerCount;
            exposedModelName = if modelAlias != null then modelAlias else modelFile;

            # CUDA 12.9's cuda_compat redistributable is not available for
            # linux-x86_64 in this pinned nixpkgs manifest. The desktop driver is
            # new enough for native CUDA 12.9, so build llama.cpp without the
            # forward-compat package and hook.
            disabledCudaCompatRunpathHook =
              pkgs.runCommand "auto-add-cuda-compat-runpath-hook-disabled"
                {
                  passthru.enableHook = false;
                }
                ''
                  mkdir -p $out/nix-support
                  touch $out/nix-support/setup-hook
                '';
            cudaPackagesWithoutCompat = pkgs.cudaPackages.overrideScope (
              _final: _prev: {
                cuda_compat = null;
                autoAddCudaCompatRunpath = disabledCudaCompatRunpathHook;
              }
            );

            mkLlamacppPackage =
              selectedBackend:
              if selectedBackend == "rocm" then
                pkgs.llamacpp-rocm-rpc
              else
                pkgs.llama-cpp.override {
                  cudaSupport = selectedBackend == "cuda";
                  cudaPackages = if selectedBackend == "cuda" then cudaPackagesWithoutCompat else { };
                  rocmSupport = false;
                  vulkanSupport = selectedBackend == "vulkan";
                  rpcSupport = false;
                };

            llamaCppPackage = mkLlamacppPackage backend;
            llamaServer = "${llamaCppPackage}/bin/llama-server";

            optionalArgs = condition: args: lib.optionals condition args;
            optionalNumberArg =
              name: value:
              optionalArgs (value > disabledNumericOption) [
                name
                (toString value)
              ];
            optionalStringArg =
              name: value:
              optionalArgs (value != null) [
                name
                value
              ];

            serverArgs = [
              llamaServer
              "--host"
              host
              "--port"
              (toString port)
              "--model"
              modelPath
              "--alias"
              exposedModelName
              "--ctx-size"
              (toString contextSize)
              "--gpu-layers"
              (toString effectiveGpuLayers)
            ]
            ++ optionalArgs flashAttention [
              "--flash-attn"
              "on"
            ]
            ++ optionalArgs noMmap [ "--no-mmap" ]
            ++ optionalArgs enableMetrics [ "--metrics" ]
            ++ optionalNumberArg "--batch-size" batchSize
            ++ optionalNumberArg "--ubatch-size" ubatchSize
            ++ optionalNumberArg "--parallel" parallelSlots
            ++ optionalStringArg "--cache-type-k" cacheTypeK
            ++ optionalStringArg "--cache-type-v" cacheTypeV
            ++ extraArgs;

            downloadModel = pkgs.writeShellApplication {
              name = "${pullServiceName}-script";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.curl
              ];
              text = ''
                set -euo pipefail

                model_dir=${lib.escapeShellArg modelsDir}
                model_path=${lib.escapeShellArg modelPath}
                partial_path="''${model_path}${partialSuffix}"
                model_url=${lib.escapeShellArg modelUrl}

                mkdir -p "$model_dir"

                if [ -f "$model_path" ]; then
                  echo "Model already present: ${modelFile}"
                  exit 0
                fi

                echo "Downloading model: ${modelRepo}/${modelFile}"
                echo "URL: $model_url"

                curl \
                  --fail \
                  --location \
                  --retry ${toString curlRetryCount} \
                  --retry-delay ${toString curlRetryDelaySeconds} \
                  --continue-at - \
                  --output "$partial_path" \
                  "$model_url"

                chmod ${modelFileMode} "$partial_path"
                mv "$partial_path" "$model_path"
                echo "Download complete: ${modelFile}"
              '';
            };
          in
          {
            assertions = [
              {
                assertion = modelRepo != "";
                message = "llamacpp-server ${instanceName}: modelRepo must not be empty";
              }
              {
                assertion = modelFile != "";
                message = "llamacpp-server ${instanceName}: modelFile must not be empty";
              }
              {
                assertion = contextSize > 0;
                message = "llamacpp-server ${instanceName}: contextSize must be positive";
              }
              {
                assertion = gpuLayers >= disabledNumericOption;
                message = "llamacpp-server ${instanceName}: gpuLayers must not be negative";
              }
              {
                assertion = batchSize >= disabledNumericOption;
                message = "llamacpp-server ${instanceName}: batchSize must not be negative";
              }
              {
                assertion = ubatchSize >= disabledNumericOption;
                message = "llamacpp-server ${instanceName}: ubatchSize must not be negative";
              }
              {
                assertion = parallelSlots >= disabledNumericOption;
                message = "llamacpp-server ${instanceName}: parallelSlots must not be negative";
              }
            ];

            environment.systemPackages = [ llamaCppPackage ];

            systemd = {
              tmpfiles.rules = [
                "d ${modelsDir} ${stateDirectoryMode} root root -"
              ];

              services = {
                ${pullServiceName} = {
                  description = "Download llama.cpp model for ${instanceName}";
                  after = [ "network-online.target" ];
                  wants = [ "network-online.target" ];
                  before = [ "${serviceName}.service" ];
                  wantedBy = lib.mkIf autoStart [ "multi-user.target" ];

                  serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                    Restart = "on-failure";
                    RestartSec = pullRestartDelay;
                    TimeoutStartSec = infiniteTimeout;
                    StateDirectory = stateDirectory;
                    StateDirectoryMode = stateDirectoryMode;
                    ExecStart = lib.getExe downloadModel;
                  };
                };

                ${serviceName} = {
                  description = "llama.cpp OpenAI-compatible server (${instanceName})";
                  after = [
                    "network-online.target"
                    "${pullServiceName}.service"
                  ];
                  wants = [ "network-online.target" ];
                  requires = [ "${pullServiceName}.service" ];
                  wantedBy = lib.mkIf autoStart [ "multi-user.target" ];

                  serviceConfig = {
                    ExecCondition = "${pkgs.coreutils}/bin/test -f ${modelPath}";
                    ExecStart = lib.escapeShellArgs serverArgs;
                    Restart = "on-failure";
                    RestartSec = serverRestartDelay;
                    User = "root";
                    Group = "root";
                    StateDirectory = stateDirectory;
                    StateDirectoryMode = stateDirectoryMode;
                  };

                  environment = {
                    HOME = stateDir;
                  };
                };
              };
            };

            networking.firewall.allowedTCPPorts = [ port ];
          };
      };
  };
}
