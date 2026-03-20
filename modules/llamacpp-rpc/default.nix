# Distributed LLM inference via llama.cpp RPC.
#
# Two roles:
#   worker — runs rpc-server exposing GPU to the cluster
#   server — runs llama-server distributing layers across local + remote GPUs
{ lib, ... }:
let
  inherit (lib)
    mkOption
    concatStringsSep
    ;
  inherit (lib.types)
    str
    int
    bool
    port
    listOf
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
                  DynamicUser = true;
                  StateDirectory = "llamacpp";

                  # GPU access
                  SupplementaryGroups = [
                    "render"
                    "video"
                  ];
                  DeviceAllow = [
                    "/dev/kfd rw"
                    "/dev/dri/* rw"
                  ];
                };

                environment = {
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
          modelPath = mkOption {
            type = str;
            default = "/var/lib/llamacpp/models/model.gguf";
            description = "Path to the GGUF model file";
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
                modelPath
                rpcWorkers
                gpuLayers
                flashAttention
                contextSize
                noMmap
                extraArgs
                ;
              pkg = pkgs.llamacpp-rocm-rpc;
              rpcFlag = lib.optionals (rpcWorkers != [ ]) [
                "--rpc"
                (concatStringsSep "," rpcWorkers)
              ];
            in
            {
              systemd.services.llamacpp-inference = {
                description = "llama.cpp inference server";
                after = [ "network-online.target" ];
                wants = [ "network-online.target" ];
                wantedBy = [ "multi-user.target" ];

                serviceConfig = {
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
                    ++ lib.optionals flashAttention [ "-fa" ]
                    ++ lib.optionals noMmap [ "--no-mmap" ]
                    ++ extraArgs
                  );
                  Restart = "on-failure";
                  RestartSec = 10;
                  DynamicUser = true;
                  StateDirectory = "llamacpp";

                  # GPU access
                  SupplementaryGroups = [
                    "render"
                    "video"
                  ];
                  DeviceAllow = [
                    "/dev/kfd rw"
                    "/dev/dri/* rw"
                  ];
                };

                environment = {
                  HSA_OVERRIDE_GFX_VERSION = "11.5.1";
                };
              };

              # Model storage directory
              systemd.tmpfiles.rules = [
                "d /var/lib/llamacpp/models 0755 root root -"
              ];

              networking.firewall.allowedTCPPorts = [ port ];
            };
        };
    };
  };
}
