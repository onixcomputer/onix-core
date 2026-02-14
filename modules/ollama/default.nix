{ lib, ... }:
let
  inherit (lib) mkOption mkIf;
  inherit (lib.types)
    str
    listOf
    port
    bool
    ;
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
            type = str;
            default = "rocm";
            description = "Acceleration type: 'rocm', 'cuda', or 'false'";
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
            in
            {
              services.ollama = {
                enable = true;
                inherit host port;
                acceleration = if enableGPU then acceleration else null;
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
                };

                script =
                  let
                    modelList = lib.concatStringsSep " " models;
                  in
                  ''
                    # Wait for Ollama to be ready
                    for i in $(seq 1 30); do
                      if ${pkgs.curl}/bin/curl -s "http://${host}:${toString port}/api/tags" >/dev/null 2>&1; then
                        break
                      fi
                      echo "Waiting for Ollama to be ready... ($i/30)"
                      sleep 2
                    done

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
