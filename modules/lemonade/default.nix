# Lemonade — OpenAI-compatible local LLM server.
#
# Runs lemond as a systemd service, configured to use the nixpkgs-built
# llamacpp-rocm-rpc binary for ROCm inference instead of downloading
# upstream binaries (which are dynamically linked against Ubuntu's glibc
# and won't run on NixOS).
{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";

  manifest = {
    name = "lemonade";
    readme = "Lemonade local LLM inference server with OpenAI-compatible API";
    description = "OpenAI-compatible local LLM, image, and speech server optimized for AMD GPUs";
    categories = [
      "AI/ML"
      "Inference"
    ];
  };

  roles = {
    default = {
      description = "Lemonade server providing OpenAI-compatible LLM endpoints";
      interface = mkSettings.mkInterface schema.default;

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            {
              pkgs,
              lib,
              ...
            }:
            let
              ms = import ../../lib/mk-settings.nix { inherit lib; };
              cfg = extendSettings (ms.mkDefaults schema.default);

              inherit (cfg)
                host
                port
                backend
                models
                contextSize
                maxLoadedModels
                extraArgs
                offline
                ;

              lemonadePkg = pkgs.lemonade-server;
              llamacppPkg = pkgs.llamacpp-rocm-rpc;

              stateDir = "/var/lib/lemonade";

              # Config JSON written to the cache dir at service start.
              # Overrides defaults.json with NixOS-managed values.
              configJson = pkgs.writeText "lemonade-config.json" (
                builtins.toJSON {
                  config_version = 1;
                  inherit host port;
                  ctx_size = contextSize;
                  max_loaded_models = maxLoadedModels;
                  inherit offline;
                  llamacpp = {
                    backend = if backend == "system" then "auto" else backend;
                    prefer_system = backend == "system";
                    # Point at nix-built llama-server to avoid runtime downloads
                    # of dynamically-linked upstream binaries.
                    rocm_bin = "${llamacppPkg}/bin/llama-server";
                    vulkan_bin = "builtin";
                    cpu_bin = "builtin";
                  }
                  // lib.optionalAttrs (extraArgs != "") {
                    args = extraArgs;
                  };
                }
              );

              pullScript = pkgs.writeShellApplication {
                name = "lemonade-model-pull";
                runtimeInputs = [
                  lemonadePkg
                  pkgs.curl
                ];
                text = ''
                  ready=false
                  for i in $(seq 1 30); do
                    if curl -sf "http://${host}:${toString port}/live" >/dev/null 2>&1; then
                      ready=true
                      break
                    fi
                    echo "Waiting for Lemonade to be ready... ($i/30)"
                    sleep 2
                  done

                  if [ "$ready" = "false" ]; then
                    echo "ERROR: Lemonade not ready after 60s"
                    exit 1
                  fi

                  for model in ${lib.concatStringsSep " " (map lib.escapeShellArg models)}; do
                    echo "Pulling model: $model"
                    lemonade pull "$model" || {
                      echo "WARNING: Failed to pull $model, will retry on next activation"
                    }
                  done
                '';
              };
            in
            {
              # Install the lemonade package system-wide for CLI access
              environment.systemPackages = [ lemonadePkg ];

              systemd.services.lemonade = {
                description = "Lemonade LLM Server";
                after = [ "network-online.target" ];
                wants = [ "network-online.target" ];
                wantedBy = [ "multi-user.target" ];

                serviceConfig = {
                  # Write our managed config.json before starting
                  ExecStartPre =
                    let
                      preScript = pkgs.writeShellApplication {
                        name = "lemonade-pre";
                        text = ''
                          mkdir -p ${stateDir}
                          cp --no-preserve=mode ${configJson} ${stateDir}/config.json
                        '';
                      };
                    in
                    lib.getExe preScript;

                  ExecStart = lib.concatStringsSep " " [
                    "${lemonadePkg}/bin/lemonade-router"
                    stateDir
                    "--host"
                    host
                    "--port"
                    (toString port)
                  ];

                  Restart = "on-failure";
                  RestartSec = 10;

                  # Root for GPU device access (kfd + dri)
                  User = "root";
                  Group = "root";
                  StateDirectory = "lemonade";
                };

                environment = {
                  HOME = stateDir;
                  LEMONADE_CACHE_DIR = stateDir;

                  # ROCm env for gfx1151
                  HSA_OVERRIDE_GFX_VERSION = "11.5.1";
                  HSA_ENABLE_SDMA = "0";
                  PYTORCH_ROCM_ARCH = "gfx1151";
                };
              };

              # Model pull service — runs after the server is up
              systemd.services.lemonade-model-pull = lib.mkIf (models != [ ]) {
                description = "Pull Lemonade models";
                after = [ "lemonade.service" ];
                requires = [ "lemonade.service" ];
                wantedBy = [ "multi-user.target" ];

                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  Restart = "on-failure";
                  RestartSec = "30s";
                  ExecStart = lib.getExe pullScript;
                };

                environment = {
                  HOME = stateDir;
                  LEMONADE_CACHE_DIR = stateDir;
                };
              };

              networking.firewall.allowedTCPPorts = [ port ];
            };
        };
    };
  };
}
