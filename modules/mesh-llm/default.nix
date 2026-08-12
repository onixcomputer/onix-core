{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
  _class = "clan.service";

  manifest = {
    name = "mesh-llm";
    readme = "Private Mesh-LLM sidecar for an existing OpenAI-compatible inference endpoint";
    description = "Routes local OpenAI-compatible models through a private Mesh-LLM node";
    categories = [
      "AI/ML"
      "Inference"
    ];
  };

  roles.default = {
    description = "Mesh-LLM private seed or joiner sidecar";
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
            isJoiner = settings.mode == "joiner";
            serviceName = "mesh-llm-${instanceName}";
            credentialPlaceholder = "Welcome to SOPS! Edit this file as you please!";
            joinTokenPath =
              if isJoiner then config.clan.core.vars.generators.${serviceName}.files."join-token".path else null;
            serviceConfig = import ./mk-nixos-config.nix {
              inherit
                config
                instanceName
                joinTokenPath
                lib
                pkgs
                settings
                ;
            };
          in
          lib.mkMerge [
            serviceConfig
            {
              clan.core.vars.generators.${serviceName} = lib.mkIf isJoiner {
                files."join-token" = {
                  secret = true;
                  deploy = true;
                  owner = "root";
                  group = "root";
                  mode = "0400";
                };
                prompts."join-token" = {
                  description = "Invite token emitted by the private Mesh-LLM seed node";
                  type = "hidden";
                  persist = true;
                };
                runtimeInputs = [ pkgs.coreutils ];
                script = ''
                  token="$(tr -d '\r\n' < "$prompts/join-token")"
                  if [ -z "$token" ] || [ "$token" = ${lib.escapeShellArg credentialPlaceholder} ]; then
                    echo "Mesh-LLM invite token is unset" >&2
                    exit 1
                  fi
                  printf '%s' "$token" > "$out/join-token"
                '';
              };
            }
          ];
      };
  };
}
