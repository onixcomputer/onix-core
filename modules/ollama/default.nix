{ lib, ... }:
let
  inherit (lib) mkOption mkIf;
  inherit (lib.types)
    str
    enum
    listOf
    port
    bool
    ;

  validAccelerationTypes = [
    "rocm"
    "cuda"
    "vulkan"
    "cpu"
  ];
in
{
  _class = "clan.service";
  manifest = {
    name = "ollama";
    readme = "Ollama LLM inference server with automatic model management";
  };

  roles = {
    default = {
      description = "Ollama server that serves LLM models locally";
      interface = {
        options = {
          host = mkOption {
            type = str;
            default = "127.0.0.1";
            description = "Host address to bind to";
          };

          port = mkOption {
            type = port;
            default = 11434;
            description = "Port for the Ollama API";
          };

          models = mkOption {
            type = listOf str;
            default = [ ];
            description = "List of models to pre-pull on activation";
          };

          enableGPU = mkOption {
            type = bool;
            default = true;
            description = "Enable GPU acceleration (ROCm for AMD, CUDA for NVIDIA)";
          };

          acceleration = mkOption {
            type = enum validAccelerationTypes;
            default = "rocm";
            description = "Acceleration type: 'rocm', 'cuda', 'vulkan', or 'cpu'";
          };
        };
      };

      perInstance =
        { settings, ... }:
        {
          nixosModule =
            { pkgs, ... }:
            let
              inherit (settings)
                host
                port
                models
                enableGPU
                acceleration
                ;
              ollamaPackage =
                if !enableGPU then
                  pkgs.ollama-cpu
                else if acceleration == "rocm" then
                  pkgs.ollama-rocm
                else if acceleration == "cuda" then
                  pkgs.ollama-cuda
                else if acceleration == "vulkan" then
                  pkgs.ollama-vulkan
                else
                  pkgs.ollama-cpu;
            in
            {
              assertions = [
                {
                  assertion = !enableGPU || acceleration != "cpu";
                  message = "ollama: enableGPU is true but acceleration is 'cpu' — set enableGPU = false or pick a GPU backend";
                }
              ];

              services.ollama = {
                enable = true;
                inherit host port;
                package = ollamaPackage;
              };

              # Pre-pull models on activation
              systemd.services.ollama-model-pull = mkIf (models != [ ]) {
                description = "Pull Ollama models";
                after = [ "ollama.service" ];
                requires = [ "ollama.service" ];
                wantedBy = [ "multi-user.target" ];

                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  Restart = "on-failure";
                  RestartSec = "30s";
                };

                environment = {
                  OLLAMA_HOST = "http://${host}:${toString port}";
                  HOME = "/var/lib/ollama";
                };

                script =
                  let
                    modelList = lib.concatStringsSep " " models;
                  in
                  ''
                    # Wait for Ollama to be ready (bounded: 30 attempts × 2s = 60s)
                    ready=false
                    for i in $(seq 1 30); do
                      if ${pkgs.curl}/bin/curl -s "http://${host}:${toString port}/api/tags" >/dev/null 2>&1; then
                        ready=true
                        break
                      fi
                      echo "Waiting for Ollama to be ready... ($i/30)"
                      sleep 2
                    done

                    if [ "$ready" = "false" ]; then
                      echo "ERROR: Ollama not ready after 60s"
                      exit 1
                    fi

                    # Pull each model
                    for model in ${modelList}; do
                      echo "Checking model: $model"
                      if ! ${pkgs.ollama}/bin/ollama list 2>/dev/null | grep -q "^$model"; then
                        echo "Pulling model: $model"
                        ${pkgs.ollama}/bin/ollama pull "$model"
                      else
                        echo "Model already present: $model"
                      fi
                    done
                  '';
              };

              networking.firewall.allowedTCPPorts = [ port ];
            };
        };
    };
  };
}
