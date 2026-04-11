{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";

  manifest = {
    name = "speaches";
    readme = "Speaches OpenAI-compatible STT and TTS server";
    description = "Local speech-to-text and text-to-speech inference with Speaches";
    categories = [
      "AI/ML"
      "Speech"
    ];
  };

  roles.default = {
    description = "Speaches speech server";
    interface = mkSettings.mkInterface schema.default;

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
            settings = extendSettings (ms.mkDefaults schema.default);

            inherit (settings)
              stateDir
              image
              host
              port
              enableGPU
              enableUi
              logLevel
              models
              modelAliases
              sttModelTtl
              ttsModelTtl
              whisperComputeType
              ;

            containerName = "speaches-${instanceName}";
            cacheDir = "${stateDir}/huggingface";
            localOnlyHosts = [
              "127.0.0.1"
              "::1"
            ];
            aliasesFile = pkgs.writeText "${containerName}-model-aliases.json" (builtins.toJSON modelAliases);
          in
          {
            networking.firewall.allowedTCPPorts = lib.optionals (!(lib.elem host localOnlyHosts)) [ port ];

            systemd.tmpfiles.rules = [
              "d ${stateDir} 0755 root root -"
              "d ${cacheDir} 0775 1000 1000 -"
            ];

            systemd.services."docker-${containerName}".preStart = ''
              install -d -m 0755 ${stateDir}
              install -d -m 0775 -o 1000 -g 1000 ${cacheDir}
            '';

            virtualisation.oci-containers = {
              backend = "docker";
              containers."${containerName}" = {
                inherit image;
                pull = "always";
                extraOptions = [ "--network=host" ] ++ lib.optionals enableGPU [ "--gpus=all" ];
                environment = {
                  HF_HUB_CACHE = "/home/ubuntu/.cache/huggingface/hub";
                  LOG_LEVEL = logLevel;
                  PRELOAD_MODELS = builtins.toJSON models;
                  SPEACHES_LOG_LEVEL = lib.toUpper logLevel;
                  STT_MODEL_TTL = toString sttModelTtl;
                  TTS_MODEL_TTL = toString ttsModelTtl;
                  UVICORN_HOST = host;
                  UVICORN_PORT = toString port;
                  ENABLE_UI = if enableUi then "true" else "false";
                  WHISPER__COMPUTE_TYPE = whisperComputeType;
                  WHISPER__INFERENCE_DEVICE = if enableGPU then "cuda" else "cpu";
                };
                volumes = [
                  "${cacheDir}:/home/ubuntu/.cache/huggingface/hub"
                  "${aliasesFile}:/home/ubuntu/speaches/model_aliases.json:ro"
                ];
              };
            };
          };
      };
  };
}
