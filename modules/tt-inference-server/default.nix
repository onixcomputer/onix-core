{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";

  manifest = {
    name = "tt-inference-server";
    readme = "Tenstorrent vLLM inference server with physical-device and secret isolation";
    description = "Runs a digest-pinned tt-inference-server image on one Tenstorrent device";
    categories = [
      "AI/ML"
      "Inference"
    ];
  };

  roles.default = {
    description = "Tenstorrent vLLM inference server";
    interface = mkSettings.mkInterface schema.default;

    perInstance =
      { instanceName, extendSettings, ... }:
      {
        nixosModule =
          {
            config,
            pkgs,
            lib,
            ...
          }:
          let
            ms = import ../../lib/mk-settings.nix { inherit lib; };
            settings = extendSettings (ms.mkDefaults schema.default);

            inherit (settings)
              stateDir
              image
              model
              device
              physicalDeviceId
              host
              port
              cacheUid
              cacheGid
              enableTraceCapture
              autoStart
              extraArgs
              ;

            generatorName = "tt-inference-server-${instanceName}";
            containerName = "tt-inference-server-${instanceName}";
            serviceName = "docker-${containerName}";
            envFile = config.clan.core.vars.generators.${generatorName}.files."env-file".path;
            cacheDir = "${stateDir}/cache-root";
            logsDir = "${stateDir}/logs";
            devicePath = "/dev/tenstorrent/${toString physicalDeviceId}";
            containerCacheDir = "/home/container_app_user/cache_root";
            containerLogsDir = "/home/container_app_user/logs";
            hugepagesMount = "/dev/hugepages-1G";

            minimumNumericId = 0;
            stateDirectoryMode = "0755";
            cacheDirectoryMode = "0775";
            secretFileMode = "0400";
            restartDelay = "30s";
            startLimitInterval = "10min";
            startLimitBurst = 3;
            stockSopsPlaceholder = "Welcome to SOPS! Edit this file as you please!";
            huggingFaceTokenPrefix = "hf_";
            loopbackHost = "127.0.0.1";

            serverArgs = [
              "--model"
              model
              "--tt-device"
              device
              "--service-port"
              (toString port)
            ]
            ++ lib.optionals (!enableTraceCapture) [ "--disable-trace-capture" ]
            ++ extraArgs;

            credentialCheck = pkgs.writeShellApplication {
              name = "${containerName}-credential-check";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.gnugrep
              ];
              text = ''
                set -euo pipefail

                env_file=${lib.escapeShellArg envFile}
                device_path=${lib.escapeShellArg devicePath}
                hugepages_mount=${lib.escapeShellArg hugepagesMount}

                if [[ ! -r "$env_file" ]]; then
                  echo "${containerName}: Hugging Face credential file is unavailable" >&2
                  exit 1
                fi
                if ! grep --extended-regexp --quiet '^HF_TOKEN=${huggingFaceTokenPrefix}[[:alnum:]]+$' "$env_file"; then
                  echo "${containerName}: Hugging Face credential is unset or malformed" >&2
                  exit 1
                fi
                if grep --fixed-strings --quiet ${lib.escapeShellArg stockSopsPlaceholder} "$env_file"; then
                  echo "${containerName}: Hugging Face credential still contains the stock SOPS placeholder" >&2
                  exit 1
                fi
                if [[ ! -c "$device_path" ]]; then
                  echo "${containerName}: physical Tenstorrent device is unavailable: $device_path" >&2
                  exit 1
                fi
                if [[ ! -d "$hugepages_mount" ]]; then
                  echo "${containerName}: hugepages mount is unavailable: $hugepages_mount" >&2
                  exit 1
                fi
              '';
            };
          in
          {
            assertions = [
              {
                assertion = lib.hasPrefix "/" stateDir;
                message = "tt-inference-server ${instanceName}: stateDir must be absolute";
              }
              {
                assertion = lib.hasInfix "@sha256:" image;
                message = "tt-inference-server ${instanceName}: image must be pinned by OCI digest";
              }
              {
                assertion = model != "";
                message = "tt-inference-server ${instanceName}: model must not be empty";
              }
              {
                assertion = builtins.isInt physicalDeviceId && physicalDeviceId >= minimumNumericId;
                message = "tt-inference-server ${instanceName}: physicalDeviceId must be a non-negative integer";
              }
              {
                assertion = builtins.isInt cacheUid && cacheUid >= minimumNumericId;
                message = "tt-inference-server ${instanceName}: cacheUid must be a non-negative integer";
              }
              {
                assertion = builtins.isInt cacheGid && cacheGid >= minimumNumericId;
                message = "tt-inference-server ${instanceName}: cacheGid must be a non-negative integer";
              }
              {
                assertion = host == loopbackHost;
                message = "tt-inference-server ${instanceName}: host must remain IPv4-loopback-only unless API authentication is added";
              }
            ];

            # r[impl onix.tenstorrent.vllm.secrets]
            clan.core.vars.generators.${generatorName} = {
              files."env-file" = {
                secret = true;
                deploy = true;
                owner = "root";
                group = "root";
                mode = secretFileMode;
              };
              prompts.huggingface-token = {
                description = "Hugging Face read token authorized for ${model}";
                type = "hidden";
                persist = true;
              };
              runtimeInputs = [ pkgs.coreutils ];
              script = ''
                token="$(tr -d '\r\n' < "$prompts/huggingface-token")"
                if [ -z "$token" ] || [ "$token" = ${lib.escapeShellArg stockSopsPlaceholder} ]; then
                  echo "Hugging Face token for ${containerName} is unset" >&2
                  exit 1
                fi
                case "$token" in
                  ${huggingFaceTokenPrefix}*) ;;
                  *)
                    echo "Hugging Face token for ${containerName} is malformed" >&2
                    exit 1
                    ;;
                esac
                token_body="''${token#${huggingFaceTokenPrefix}}"
                case "$token_body" in
                  ""|*[![:alnum:]]*)
                    echo "Hugging Face token for ${containerName} contains an invalid token body" >&2
                    exit 1
                    ;;
                  *) ;;
                esac
                printf 'HF_TOKEN=%s\n' "$token" > "$out/env-file"
              '';
            };

            systemd.tmpfiles.rules = [
              "d ${stateDir} ${stateDirectoryMode} ${toString cacheUid} ${toString cacheGid} -"
              "d ${cacheDir} ${cacheDirectoryMode} ${toString cacheUid} ${toString cacheGid} -"
              "d ${logsDir} ${cacheDirectoryMode} ${toString cacheUid} ${toString cacheGid} -"
            ];

            # r[impl onix.tenstorrent.vllm.p150_llama]
            virtualisation.oci-containers = {
              backend = "docker";
              containers.${containerName} = {
                inherit image autoStart;
                pull = "always";
                environmentFiles = [ envFile ];
                environment = {
                  CACHE_ROOT = containerCacheDir;
                  TT_METAL_LOGS_PATH = containerLogsDir;
                  TT_VISIBLE_DEVICES = toString physicalDeviceId;
                };
                cmd = serverArgs;
                ports = [ "${host}:${toString port}:${toString port}" ];
                extraOptions = [
                  "--ipc=host"
                  "--device=${devicePath}:${devicePath}"
                  "--mount=type=bind,src=${hugepagesMount},dst=${hugepagesMount}"
                ];
                volumes = [
                  "${cacheDir}:${containerCacheDir}"
                  "${logsDir}:${containerLogsDir}"
                ];
              };
            };

            systemd.services.${serviceName} = {
              after = [
                "docker.service"
                "network-online.target"
              ];
              wants = [ "network-online.target" ];
              unitConfig = {
                ConditionPathExists = [
                  envFile
                  devicePath
                  hugepagesMount
                ];
                StartLimitIntervalSec = startLimitInterval;
                StartLimitBurst = startLimitBurst;
              };
              serviceConfig = {
                ExecCondition = lib.getExe credentialCheck;
                Restart = "on-failure";
                RestartSec = restartDelay;
              };
            };
          };
      };
  };
}
