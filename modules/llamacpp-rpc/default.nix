# Distributed LLM inference via llama.cpp RPC.
#
# Two roles:
#   worker — runs rpc-server exposing GPU to the cluster
#   server — runs llama-server distributing layers across local + remote GPUs
{ lib, ... }:
let
  inherit (lib)
    mkOption
    mkIf
    concatStringsSep
    ;
  inherit (lib.types)
    str
    int
    bool
    port
    listOf
    nullOr
    submodule
    ;
in
{
  _class = "clan.service";

  manifest = {
    name = "llamacpp-rpc";
    description = "Distributed LLM inference via llama.cpp RPC over high-speed interconnect";
    categories = [
      "AI/ML"
      "Inference"
    ];
  };

  roles = {
    # ── Worker role ──────────────────────────────────────────────
    worker = {
      description = "RPC worker node exposing GPU to the inference cluster";
      interface = {
        options = {
          bindAddress = mkOption {
            type = str;
            default = "0.0.0.0";
            description = "Address to bind the RPC server to";
          };
          port = mkOption {
            type = port;
            default = 50052;
            description = "Port for the RPC server";
          };
          enableCache = mkOption {
            type = bool;
            default = true;
            description = "Enable local tensor cache to avoid re-transfers on reconnect";
          };
        };
      };

      perInstance =
        { settings, ... }:
        {
          nixosModule =
            { pkgs, ... }:
            let
              inherit (settings) bindAddress port enableCache;
              pkg = pkgs.llamacpp-rocm-rpc;
            in
            {
              systemd.services.llamacpp-rpc-worker = {
                description = "llama.cpp RPC worker";
                after = [ "network-online.target" ];
                wants = [ "network-online.target" ];
                wantedBy = [ "multi-user.target" ];

                serviceConfig = {
                  ExecStart = concatStringsSep " " (
                    [
                      "${pkg}/bin/llama-rpc-server"
                      "--host"
                      bindAddress
                      "--port"
                      (toString port)
                    ]
                    ++ lib.optionals enableCache [ "-c" ]
                  );
                  Restart = "on-failure";
                  RestartSec = 5;

                  # Run as root for GPU device access (kfd + dri).
                  # DynamicUser can't access /dev/kfd reliably.
                  User = "root";
                  Group = "root";
                  StateDirectory = "llamacpp";
                };

                environment = {
                  HOME = "/var/lib/llamacpp";
                  HSA_OVERRIDE_GFX_VERSION = "11.5.1";
                };
              };

              networking.firewall.allowedTCPPorts = [ port ];
            };
        };
    };

    # ── Server role ──────────────────────────────────────────────
    server = {
      description = "Main inference node running llama-server with RPC backends";
      interface = {
        options = {
          host = mkOption {
            type = str;
            default = "0.0.0.0";
            description = "Address to bind the API server to";
          };
          port = mkOption {
            type = port;
            default = 8081;
            description = "Port for the OpenAI-compatible API";
          };
          model = mkOption {
            type = nullOr (submodule {
              options = {
                repo = mkOption {
                  type = str;
                  description = "HuggingFace repository (e.g. unsloth/Qwen3.5-122B-A10B-GGUF)";
                };
                file = mkOption {
                  type = str;
                  description = "GGUF filename within the repository";
                };
              };
            });
            default = null;
            description = "HuggingFace model to download. Null disables auto-download.";
          };
          rpcWorkers = mkOption {
            type = listOf str;
            default = [ ];
            description = "List of RPC worker addresses (host:port)";
          };
          gpuLayers = mkOption {
            type = int;
            default = 999;
            description = "Number of layers to offload to GPU (-ngl)";
          };
          flashAttention = mkOption {
            type = bool;
            default = true;
            description = "Enable flash attention (-fa) for faster long-context inference";
          };
          contextSize = mkOption {
            type = int;
            default = 8192;
            description = "Context window size (-c)";
          };
          noMmap = mkOption {
            type = bool;
            default = true;
            description = "Disable mmap (required for stable RPC model distribution)";
          };
          extraArgs = mkOption {
            type = listOf str;
            default = [ ];
            description = "Additional llama-server command-line arguments";
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
                model
                rpcWorkers
                gpuLayers
                flashAttention
                contextSize
                noMmap
                extraArgs
                ;
              pkg = pkgs.llamacpp-rocm-rpc;
              modelsDir = "/var/lib/llamacpp/models";
              modelPath = if model != null then "${modelsDir}/${model.file}" else "${modelsDir}/model.gguf";
              rpcFlag = lib.optionals (rpcWorkers != [ ]) [
                "--rpc"
                (concatStringsSep "," rpcWorkers)
              ];
            in
            {
              systemd = {
                services = {
                  # ── Model download service ───────────────────────────
                  llamacpp-model-pull = mkIf (model != null) {
                    description = "Download llama.cpp GGUF model from HuggingFace";
                    after = [ "network-online.target" ];
                    wants = [ "network-online.target" ];
                    wantedBy = [ "multi-user.target" ];
                    before = [ "llamacpp-inference.service" ];

                    serviceConfig = {
                      Type = "oneshot";
                      RemainAfterExit = true;
                      Restart = "on-failure";
                      RestartSec = "60s";
                      TimeoutStartSec = "infinity";
                    };

                    environment.HOME = "/var/lib/llamacpp";

                    script = ''
                      MODEL_DIR="${modelsDir}"
                      MODEL_FILE="${model.file}"
                      MODEL_PATH="$MODEL_DIR/$MODEL_FILE"
                      MODEL_URL="https://huggingface.co/${model.repo}/resolve/main/$MODEL_FILE"

                      mkdir -p "$MODEL_DIR"

                      if [ -f "$MODEL_PATH" ]; then
                        echo "Model already present: $MODEL_FILE"
                        exit 0
                      fi

                      echo "Downloading model: ${model.repo}/$MODEL_FILE"
                      echo "URL: $MODEL_URL"

                      # Download with resume support for large files
                      ${pkgs.curl}/bin/curl \
                        --location \
                        --retry 5 \
                        --retry-delay 10 \
                        --continue-at - \
                        --output "$MODEL_PATH.partial" \
                        "$MODEL_URL"

                      mv "$MODEL_PATH.partial" "$MODEL_PATH"
                      echo "Download complete: $MODEL_FILE ($(du -h "$MODEL_PATH" | cut -f1))"
                    '';
                  };

                  # ── Inference server ─────────────────────────────────
                  llamacpp-inference = {
                    description = "llama.cpp inference server";
                    after = [
                      "network-online.target"
                    ]
                    ++ lib.optionals (model != null) [ "llamacpp-model-pull.service" ];
                    wants = [ "network-online.target" ];
                    requires = lib.optionals (model != null) [ "llamacpp-model-pull.service" ];
                    wantedBy = [ "multi-user.target" ];

                    serviceConfig = {
                      ExecCondition = "${pkgs.bash}/bin/bash -c 'test -f ${modelPath}'";
                      ExecStart = concatStringsSep " " (
                        [
                          "${pkg}/bin/llama-server"
                          "--host"
                          host
                          "--port"
                          (toString port)
                          "-m"
                          modelPath
                          "-ngl"
                          (toString gpuLayers)
                          "-c"
                          (toString contextSize)
                        ]
                        ++ rpcFlag
                        ++ lib.optionals flashAttention [
                          "-fa"
                          "on"
                        ]
                        ++ lib.optionals noMmap [ "--no-mmap" ]
                        ++ extraArgs
                      );
                      Restart = "on-failure";
                      RestartSec = 10;

                      # Run as root for GPU device access (kfd + dri)
                      User = "root";
                      Group = "root";
                      StateDirectory = "llamacpp";
                    };

                    environment = {
                      HOME = "/var/lib/llamacpp";
                      HSA_OVERRIDE_GFX_VERSION = "11.5.1";
                    };
                  };
                };

                # Model storage directory
                tmpfiles.rules = [
                  "d /var/lib/llamacpp/models 0755 root root -"
                ];
              };

              networking.firewall.allowedTCPPorts = [ port ];
            };
        };
    };
  };
}
