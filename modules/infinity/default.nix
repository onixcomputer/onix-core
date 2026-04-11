{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";

  manifest = {
    name = "infinity";
    readme = "Infinity OpenAI-compatible embeddings server";
    description = "Local embeddings inference with Infinity";
    categories = [
      "AI/ML"
      "Inference"
    ];
  };

  roles.default = {
    description = "Infinity embeddings server";
    interface = mkSettings.mkInterface schema.default;

    perInstance =
      { instanceName, extendSettings, ... }:
      {
        nixosModule =
          {
            lib,
            ...
          }:
          let
            ms = import ../../lib/mk-settings.nix { inherit lib; };
            settings = extendSettings (ms.mkDefaults schema.default);

            inherit (settings)
              stateDir
              image
              host
              port
              modelId
              servedModelName
              enableGPU
              engine
              device
              extraArgs
              ;

            containerName = "infinity-${instanceName}";
            cacheDir = "${stateDir}/cache";
            localOnlyHosts = [
              "127.0.0.1"
              "::1"
            ];
          in
          {
            networking.firewall.allowedTCPPorts = lib.optionals (!(lib.elem host localOnlyHosts)) [ port ];

            systemd.tmpfiles.rules = [
              "d ${stateDir} 0755 root root -"
              "d ${cacheDir} 0755 root root -"
            ];

            systemd.services."docker-${containerName}".preStart = ''
              install -d -m 0755 ${stateDir}
              install -d -m 0755 ${cacheDir}
            '';

            virtualisation.oci-containers = {
              backend = "docker";
              containers."${containerName}" = {
                inherit image;
                pull = "always";
                extraOptions = [ "--network=host" ] ++ lib.optionals enableGPU [ "--gpus=all" ];
                environment = {
                  HF_HOME = "/app/.cache";
                  INFINITY_ANONYMOUS_USAGE_STATS = "0";
                };
                cmd = [
                  "v2"
                  "--host"
                  host
                  "--port"
                  (toString port)
                  "--model-id"
                  modelId
                  "--served-model-name"
                  servedModelName
                  "--engine"
                  engine
                  "--device"
                  device
                ]
                ++ extraArgs;
                volumes = [ "${cacheDir}:/app/.cache" ];
              };
            };
          };
      };
  };
}
