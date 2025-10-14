{ lib, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types)
    bool
    str
    nullOr
    listOf
    attrsOf
    anything
    enum
    port
    ;
in
{
  _class = "clan.service";

  manifest = {
    name = "llm";
    description = "LLM Inference Service - Large Language Model serving";
    categories = [
      "AI/ML"
      "Inference"
    ];
  };

  roles = {
    # LLM server role - runs inference servers
    server = {
      interface = {
        # Allow freeform configuration that maps directly to underlying services
        freeformType = attrsOf anything;

        options = {
          # Service type selection
          serviceType = mkOption {
            type = enum [
              "ollama"
              "vllm"
              "llamacpp"
              "openai-compatible"
            ];
            default = "ollama";
            description = "Type of LLM service to run";
          };

          # Basic server configuration
          port = mkOption {
            type = port;
            default = 11434; # ollama default, vllm uses 8000
            description = "Port for the LLM service";
          };

          host = mkOption {
            type = str;
            default = "0.0.0.0";
            description = "Host address to bind to";
          };

          # Model configuration
          models = mkOption {
            type = listOf str;
            default = [ ];
            description = "List of models to download and serve (ollama) or model path (vllm)";
          };

          # Primary model for vLLM (first model in the list or separate option)
          model = mkOption {
            type = nullOr str;
            default = null;
            description = "Primary model to serve (used by vllm, falls back to first item in models list)";
          };

          # Resource limits
          enableGPU = mkOption {
            type = bool;
            default = true;
            description = "Enable GPU acceleration if available";
          };
        };
      };

      perInstance =
        { settings, ... }:
        {
          nixosModule =
            {
              pkgs,
              lib,
              ...
            }:
            let
              inherit (settings)
                serviceType
                port
                host
                enableGPU
                models
                model
                ;

              # Remove our wrapper options for service-specific config
              serviceConfig = builtins.removeAttrs settings [
                "serviceType"
                "port"
                "host"
                "models"
                "model"
                "enableGPU"
              ];

              # Base configuration for all services
              baseConfig = {
                enable = true;
                inherit port host;
              };

              # Final configuration merging base + user config
              finalConfig = baseConfig // serviceConfig;

            in
            {
              # Enable the specific LLM service
              services = lib.mkMerge [
                (lib.mkIf (serviceType == "ollama") {
                  ollama = finalConfig // {
                    acceleration = lib.mkIf enableGPU "rocm";
                  };
                })

                (lib.mkIf (serviceType == "vllm") {
                  # Custom vLLM systemd service since nixpkgs doesn't have one
                })

                # Placeholder for other service types
                (lib.mkIf (serviceType == "llamacpp") {
                  # llamacpp configuration would go here
                })
              ];

              # Open firewall for the service
              networking.firewall.allowedTCPPorts = [ port ];

              # Custom vLLM systemd service
              systemd.services = lib.mkIf (serviceType == "vllm") {
                vllm = {
                  description = "vLLM Inference Server";
                  wantedBy = [ "multi-user.target" ];
                  after = [ "network.target" ];

                  environment = {
                    # Set environment variables for vLLM
                    CUDA_VISIBLE_DEVICES = lib.mkIf enableGPU "0";
                  };

                  serviceConfig = {
                    Type = "simple";
                    User = "vllm";
                    Group = "vllm";
                    ExecStart =
                      let
                        # Use model parameter or first model from models list
                        primaryModel =
                          if model != null then
                            model
                          else if models != [ ] then
                            builtins.head models
                          else
                            throw "vLLM requires either 'model' or 'models' to be specified";

                        vllmArgs = [
                          "${pkgs.vllm}/bin/vllm"
                          "serve"
                          primaryModel
                          "--host"
                          host
                          "--port"
                          (toString port)
                        ]
                        ++ lib.optionals enableGPU [
                          "--tensor-parallel-size=1"
                          "--gpu-memory-utilization=0.9"
                        ]
                        ++ (settings.extraArgs or [ ]);
                      in
                      "${lib.concatStringsSep " " vllmArgs}";
                    Restart = "always";
                    RestartSec = "10";
                  };
                };
              };

              # Create vllm user for the service
              users = lib.mkIf (serviceType == "vllm") {
                users.vllm = {
                  isSystemUser = true;
                  group = "vllm";
                  description = "vLLM service user";
                };
                groups.vllm = { };
              };

              # Install client tools
              environment.systemPackages = lib.mkMerge [
                (lib.mkIf (serviceType == "ollama") [
                  pkgs.ollama
                ])
                (lib.mkIf (serviceType == "vllm") [
                  pkgs.vllm
                ])
              ];
            };
        };
    };

    # LLM client role - installs client tools and configuration
    client = {
      interface = {
        freeformType = attrsOf anything;

        options = {
          # Client configuration
          defaultServer = mkOption {
            type = nullOr str;
            default = null;
            description = "Default LLM server endpoint (e.g., http://server:11434)";
          };

          clientType = mkOption {
            type = enum [
              "ollama"
              "vllm"
              "openai"
              "curl"
            ];
            default = "ollama";
            description = "Type of client tools to install";
          };

          # Additional client packages
          extraPackages = mkOption {
            type = listOf str;
            default = [ ];
            description = "Additional packages to install for LLM clients";
          };
        };
      };

      perInstance =
        { settings, ... }:
        {
          nixosModule =
            {
              pkgs,
              lib,
              ...
            }:
            let
              inherit (settings) clientType defaultServer extraPackages;

              # Import custom goose package
              goose-cli-latest = import ./goose-cli-latest.nix { inherit pkgs; };

              # Client packages based on type
              clientPackages =
                (lib.optionals (clientType == "ollama") [
                  pkgs.ollama
                  goose-cli-latest
                  pkgs.opencode
                ])
                ++ (lib.optionals (clientType == "vllm") [
                  pkgs.vllm
                  pkgs.python3Packages.openai # vLLM provides OpenAI-compatible API
                ])
                ++ (lib.optionals (clientType == "openai") [ pkgs.python3Packages.openai ])
                ++ (lib.optionals (clientType == "curl") [
                  pkgs.curl
                  pkgs.jq
                ]);

              # Additional user-specified packages
              allPackages = clientPackages ++ (map (pkg: pkgs.${pkg}) extraPackages);

            in
            {
              # Install client packages
              environment.systemPackages = allPackages;

              # Configure default server if specified
              environment.variables = lib.mkIf (defaultServer != null) {
                OLLAMA_HOST = lib.mkIf (clientType == "ollama") defaultServer;
                OPENAI_BASE_URL = lib.mkIf (clientType == "openai" || clientType == "vllm") defaultServer;
              };
            };
        };
    };
  };
}
