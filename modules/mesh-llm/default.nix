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
      {
        instanceName,
        extendSettings,
        machine,
        roles,
        ...
      }:
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
            invitesGeneratorName = "${serviceName}-invites";
            credentialPlaceholder = "Welcome to SOPS! Edit this file as you please!";
            instanceMachines = roles.default.machines or { };
            nodeNames = lib.attrNames instanceMachines;
            modeOf = name: (instanceMachines.${name}.settings or { }).mode or schema.default.mode.default;
            peerNames = lib.filter (name: name != machine.name) nodeNames;
            # A joiner dials every other node, joiners first because they stay up the most.
            # The seed goes last: it originates the mesh ID and may be offline, and every
            # unreachable token before the first reachable one delays startup.
            orderedPeerNames =
              lib.sort lib.lessThan (lib.filter (name: modeOf name == "joiner") peerNames)
              ++ lib.sort lib.lessThan (lib.filter (name: modeOf name != "joiner") peerNames);
            joinTokens = lib.optionals isJoiner (
              map (peer: {
                name = "invite-${peer}";
                path = config.clan.core.vars.generators.${invitesGeneratorName}.files.${peer}.path;
              }) orderedPeerNames
            );
            serviceConfig = import ./mk-nixos-config.nix {
              inherit
                config
                instanceName
                joinTokens
                lib
                pkgs
                settings
                ;
            };
          in
          lib.mkMerge [
            serviceConfig
            {
              # One shared invite token per node, read from that node's /api/status.
              clan.core.vars.generators.${invitesGeneratorName} = lib.mkIf isJoiner {
                share = true;
                files = lib.genAttrs nodeNames (_: {
                  secret = true;
                  deploy = true;
                  owner = "root";
                  group = "root";
                  mode = "0400";
                });
                prompts = lib.genAttrs nodeNames (name: {
                  description = "Invite token of ${name}'s Mesh-LLM sidecar (the token field of its /api/status)";
                  type = "hidden";
                  persist = true;
                });
                runtimeInputs = [ pkgs.coreutils ];
                script = lib.concatMapStringsSep "\n" (name: ''
                  token="$(tr -d '\r\n' < "$prompts/${name}")"
                  if [ -z "$token" ] || [ "$token" = ${lib.escapeShellArg credentialPlaceholder} ]; then
                    echo "Mesh-LLM invite token for ${name} is unset" >&2
                    exit 1
                  fi
                  printf '%s' "$token" > "$out/${name}"
                '') nodeNames;
              };
            }
          ];
      };
  };
}
