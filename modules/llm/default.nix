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
    readme = "Large Language Model inference service for AI text generation and completion";
    categories = [
      "AI/ML"
      "Inference"
    ];
  };

  roles = {
    # LLM server role - runs inference servers
    server = {
      description = "LLM inference server that provides AI model endpoints";
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

          # vLLM-specific container image (for ROCm/AMD GPU support)
          containerImage = mkOption {
            type = nullOr str;
            default = null;
            description = ''
              Custom container image for vLLM. If null, uses the default
              gfx1151 (Strix Halo) ROCm image. For other AMD GPUs, specify
              an appropriate ROCm vLLM image.
            '';
          };

          # Extra environment variables for the container
          extraEnv = mkOption {
            type = attrsOf str;
            default = { };
            description = "Extra environment variables for the vLLM container";
          };

          # Auto-start control
          autoStart = mkOption {
            type = bool;
            default = true;
            description = "Whether to start the service automatically on boot. Set to false to require manual start.";
          };
        };
      };

      perInstance =
        { settings, ... }:
        {
          # Export this server's metrics endpoint so Prometheus can discover it
          exports.serviceEndpoints.llm = {
            url = "http://localhost:${toString settings.port}";
            inherit (settings) port;
          };

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
                enableGPU
                models
                model
                ;

              # Remove our wrapper options for service-specific config

              # Base configuration for all services

              # Final configuration merging base + user config

            in
            {
              # Enable the specific LLM service
              services = lib.mkMerge [
                # (lib.mkIf (serviceType == "ollama") {
                # ollama = finalConfig // {
                #   acceleration = lib.mkIf enableGPU "rocm";
                # };
                # })

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

              # Custom vLLM systemd service using OCI container (ROCm compatible)
              # nixpkgs vLLM is CUDA-only, so we use containers for AMD GPUs
              systemd.services = lib.mkIf (serviceType == "vllm") {
                vllm =
                  let
                    # Use model parameter or first model from models list
                    primaryModel =
                      if model != null then
                        model
                      else if models != [ ] then
                        builtins.head models
                      else
                        throw "vLLM requires either 'model' or 'models' to be specified";

                    # Container image: user-specified or default gfx1151 ROCm image
                    containerImage =
                      if settings.containerImage != null then
                        settings.containerImage
                      else
                        "docker.io/kyuz0/vllm-therock-gfx1151:latest";

                    # Get extra args or empty list
                    extraArgs = if settings ? extraArgs && settings.extraArgs != null then settings.extraArgs else [ ];

                    # Get extra environment variables
                    extraEnv = if settings ? extraEnv && settings.extraEnv != null then settings.extraEnv else { };

                    # Check if extraArgs already contains gpu-memory-utilization
                    hasGpuMemUtil = lib.any (arg: lib.hasPrefix "--gpu-memory-utilization" arg) extraArgs;

                    # Build vLLM command arguments
                    vllmCmd = [
                      "vllm"
                      "serve"
                      primaryModel
                      "--host"
                      "0.0.0.0"
                      "--port"
                      (toString port)
                    ]
                    ++ lib.optionals enableGPU [
                      "--tensor-parallel-size"
                      "1"
                    ]
                    # Only add default gpu-memory-utilization if not specified in extraArgs
                    ++ lib.optionals (enableGPU && !hasGpuMemUtil) [
                      "--gpu-memory-utilization"
                      "0.85"
                    ]
                    ++ extraArgs;

                    vllmCmdStr = lib.concatStringsSep " " vllmCmd;

                    # Build extra environment variable flags
                    extraEnvList = lib.mapAttrsToList (name: value: "-e ${name}=${value}") extraEnv;
                    extraEnvFlags = if extraEnvList == [ ] then "" else lib.concatStringsSep " \\\n  " extraEnvList;
                  in
                  {
                    description = "vLLM Inference Server (Container)";
                    # Only auto-start if autoStart is true (default)
                    wantedBy = lib.mkIf (settings.autoStart or true) [ "multi-user.target" ];
                    after = [
                      "network.target"
                      "docker.service"
                    ];
                    requires = [ "docker.service" ];

                    serviceConfig = {
                      Type = "simple";

                      # State directory for model cache
                      StateDirectory = "vllm";
                      StateDirectoryMode = "0755";

                      # Pull image if not present, but don't fail if already present
                      # Use script to handle errors gracefully and avoid timeout issues
                      ExecStartPre = pkgs.writeShellScript "vllm-pull-image" ''
                        # Stop any existing container with the same name
                        ${pkgs.docker}/bin/docker stop vllm-server 2>/dev/null || true
                        ${pkgs.docker}/bin/docker rm vllm-server 2>/dev/null || true

                        # Check if image exists, if not pull it
                        if ! ${pkgs.docker}/bin/docker image inspect ${containerImage} >/dev/null 2>&1; then
                          echo "Pulling container image: ${containerImage}"
                          ${pkgs.docker}/bin/docker pull ${containerImage} || {
                            echo "Failed to pull image, will retry on next restart"
                            exit 1
                          }
                        else
                          echo "Image ${containerImage} already present"
                        fi
                      '';

                      ExecStart = pkgs.writeShellScript "run-vllm-container" ''
                        exec ${pkgs.docker}/bin/docker run \
                          --rm \
                          --name vllm-server \
                          --network host \
                          --device /dev/kfd \
                          --device /dev/dri \
                          --group-add video \
                          --group-add render \
                          --ipc host \
                          --cap-add SYS_PTRACE \
                          --security-opt seccomp=unconfined \
                          --memory=115g \
                          --memory-swap=115g \
                          --oom-kill-disable=false \
                          -e HSA_ENABLE_SDMA=0 \
                          -e HIP_VISIBLE_DEVICES=0 \
                          -e VLLM_WORKER_MULTIPROC_METHOD=spawn \
                          -e TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1 \
                          -e PYTORCH_TUNABLEOP_ENABLED=1 \
                          -e PYTORCH_HIP_ALLOC_CONF=expandable_segments:True \
                          -e HSA_XNACK=1 \
                          -e PYTORCH_ROCM_ARCH=gfx1151 \
                          -e HSA_OVERRIDE_GFX_VERSION=11.5.1 \
                          ${lib.optionalString (extraEnvFlags != "") extraEnvFlags} \
                          -v /var/lib/vllm:/root/.cache/huggingface \
                          ${containerImage} \
                          ${vllmCmdStr}
                      '';

                      ExecStop = "${pkgs.docker}/bin/docker stop vllm-server";

                      Restart = "on-failure";
                      RestartMaxDelaySec = "5min";

                      # Prevent OOM from taking down the host
                      OOMPolicy = "stop";
                      OOMScoreAdjust = 500;
                      RestartSec = "30";
                      TimeoutStartSec = "3600"; # 60 minutes for initial container pull (large images)
                    };
                  };
              };

              # Create vllm directory for model cache
              systemd.tmpfiles.rules = lib.mkIf (serviceType == "vllm") [
                "d /var/lib/vllm 0755 root root -"
              ];

              # Install client tools (curl/jq for API access)
              environment.systemPackages = lib.mkMerge [
                (lib.mkIf (serviceType == "ollama") [
                  pkgs.ollama
                ])
                (lib.mkIf (serviceType == "vllm") [
                  pkgs.curl
                  pkgs.jq
                  pkgs.python3Packages.openai # OpenAI-compatible client
                ])
              ];
            };
        };
    };

    # LLM client role - installs client tools and configuration
    client = {
      description = "LLM client that connects to and uses LLM inference servers";
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
