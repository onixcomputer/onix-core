{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
  mkLaunchArgs = import ./mk-launch-args.nix { inherit lib; };
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

            inherit (settings)
              mode
              endpointUrl
              proxyActivationModel
              proxyActivationContextSize
              apiPort
              consolePort
              meshBindAddress
              meshBindInterface
              meshPort
              nodeName
              backendUnit
              ;

            isJoiner = mode == "joiner";
            package = pkgs.mesh-llm;
            serviceName = "mesh-llm-${instanceName}";
            serviceUser = "mesh-llm";
            generatorName = serviceName;
            stateDirectory = serviceName;
            statePath = "/var/lib/${stateDirectory}";
            wildcardMeshBindAddresses = [
              "0.0.0.0"
              "::"
            ];
            dynamicMeshBindAddressPlaceholder = "__mesh_bind_address__";
            hasStaticMeshBindAddress = !(builtins.elem meshBindAddress wildcardMeshBindAddresses);
            hasMeshBindInterface = meshBindInterface != null && meshBindInterface != "";
            effectiveMeshBindAddress =
              if hasMeshBindInterface then dynamicMeshBindAddressPlaceholder else meshBindAddress;
            effectiveNodeName =
              if nodeName == null || nodeName == "" then config.networking.hostName else nodeName;
            joinTokenPath =
              if isJoiner then
                config.clan.core.vars.generators.${generatorName}.files."join-token".path
              else
                null;

            configFile = pkgs.writeText "${serviceName}-config.toml" ''
              version = 1

              [[plugin]]
              name = "openai-endpoint"
              command = "${package}/bin/openai-endpoint"
              url = ${builtins.toJSON endpointUrl}
            '';

            launchArgs = mkLaunchArgs {
              inherit package settings;
              configPath = configFile;
              nodeName = effectiveNodeName;
              meshBindAddress = effectiveMeshBindAddress;
            };
            launchCommandTemplate = lib.escapeShellArgs launchArgs;
            interfaceLauncher =
              if hasMeshBindInterface then
                pkgs.writeShellApplication {
                  name = "${serviceName}-interface-launcher";
                  runtimeInputs = [
                    pkgs.iproute2
                    pkgs.jq
                  ];
                  text = ''
                    mesh_interface=${lib.escapeShellArg meshBindInterface}
                    mesh_bind_address="$(
                      ip -json -4 address show dev "$mesh_interface" \
                        | jq -er '.[0].addr_info | map(select(.scope == "global")) | .[0].local'
                    )"
                    if [ -z "$mesh_bind_address" ]; then
                      echo "${serviceName}: interface $mesh_interface has no global IPv4 address" >&2
                      exit 1
                    fi
                    exec ${
                      lib.replaceStrings
                        [ (lib.escapeShellArg dynamicMeshBindAddressPlaceholder) ]
                        [ ''"$mesh_bind_address"'' ]
                        launchCommandTemplate
                    } "$@"
                  '';
                }
              else
                null;
            launchCommand =
              if hasMeshBindInterface then
                lib.escapeShellArg (lib.getExe interfaceLauncher)
              else
                launchCommandTemplate;

            credentialPlaceholder = "Welcome to SOPS! Edit this file as you please!";
            minimumProxyActivationContextSize = 512;
            joinLauncher = pkgs.writeShellApplication {
              name = "${serviceName}-join";
              runtimeInputs = [ pkgs.coreutils ];
              text = ''
                token_file="''${CREDENTIALS_DIRECTORY:?systemd credentials are unavailable}/join-token"
                if [ ! -r "$token_file" ]; then
                  echo "${serviceName}: join credential is missing" >&2
                  exit 1
                fi

                token="$(tr -d '\r\n' < "$token_file")"
                if [ -z "$token" ] || [ "$token" = ${lib.escapeShellArg credentialPlaceholder} ]; then
                  echo "${serviceName}: join credential is unset" >&2
                  exit 1
                fi

                exec ${launchCommand} "$token"
              '';
            };

            interfaceUnits = lib.optional (meshBindInterface == "tailscale0") "tailscaled.service";
            backendUnits = lib.optional (backendUnit != null && backendUnit != "") backendUnit;
            restartDelay = "10s";
            stopTimeout = "30s";
          in
          {
            assertions = [
              {
                assertion = hasStaticMeshBindAddress != hasMeshBindInterface;
                message = "${serviceName}: set exactly one private meshBindAddress or meshBindInterface.";
              }
              {
                assertion =
                  !hasStaticMeshBindAddress || (!(lib.hasPrefix "127." meshBindAddress) && meshBindAddress != "::1");
                message = "${serviceName}: meshBindAddress must be reachable by the other mesh node, not loopback.";
              }
              {
                assertion = !hasMeshBindInterface || builtins.match "^[a-zA-Z0-9_.:-]+$" meshBindInterface != null;
                message = "${serviceName}: meshBindInterface contains unsupported characters.";
              }
              {
                assertion = lib.hasPrefix "http://127.0.0.1:" endpointUrl && lib.hasSuffix "/v1" endpointUrl;
                message = "${serviceName}: endpointUrl must be a loopback OpenAI-compatible /v1 endpoint.";
              }
              {
                assertion = proxyActivationModel != "";
                message = "${serviceName}: proxyActivationModel must name the CPU model that activates the plugin-aware proxy.";
              }
              {
                assertion = proxyActivationContextSize >= minimumProxyActivationContextSize;
                message = "${serviceName}: proxyActivationContextSize must be at least ${toString minimumProxyActivationContextSize}.";
              }
              {
                assertion = apiPort != consolePort && apiPort != meshPort && consolePort != meshPort;
                message = "${serviceName}: apiPort, consolePort, and meshPort must be distinct.";
              }
            ];

            environment.systemPackages = [ package ];

            clan.core.vars.generators.${generatorName} = lib.mkIf isJoiner {
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

            users.groups.${serviceUser} = { };
            users.users.${serviceUser} = {
              isSystemUser = true;
              group = serviceUser;
              home = statePath;
            };

            systemd.tmpfiles.rules = [ "Z ${statePath} - ${serviceUser} ${serviceUser} -" ];

            systemd.services.${serviceName} = {
              description = "Private Mesh-LLM sidecar (${instanceName}, ${mode})";
              wantedBy = [ "multi-user.target" ];
              wants = [ "network-online.target" ] ++ interfaceUnits ++ backendUnits;
              after = [ "network-online.target" ] ++ interfaceUnits ++ backendUnits;

              environment = {
                HOME = statePath;
                LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ];
                MESH_LLM_NO_SELF_UPDATE = "1";
              }
              // lib.optionalAttrs hasMeshBindInterface {
                MESH_LLM_BIND_INTERFACE = meshBindInterface;
              };

              serviceConfig = {
                Type = "simple";
                User = serviceUser;
                Group = serviceUser;
                StateDirectory = stateDirectory;
                StateDirectoryMode = "0700";
                WorkingDirectory = statePath;
                ExecStart = if isJoiner then lib.getExe joinLauncher else launchCommand;
                LoadCredential = lib.optionals isJoiner [ "join-token:${joinTokenPath}" ];
                Restart = "on-failure";
                RestartSec = restartDelay;
                TimeoutStopSec = stopTimeout;

                CapabilityBoundingSet = "";
                LockPersonality = true;
                MemoryDenyWriteExecute = false;
                NoNewPrivileges = true;
                PrivateDevices = true;
                PrivateTmp = true;
                ProtectClock = true;
                ProtectControlGroups = true;
                ProtectHome = true;
                ProtectHostname = true;
                ProtectKernelLogs = true;
                ProtectKernelModules = true;
                ProtectKernelTunables = true;
                ProtectSystem = "strict";
                RemoveIPC = true;
                RestrictAddressFamilies = [
                  "AF_INET"
                  "AF_INET6"
                  "AF_UNIX"
                ];
                RestrictNamespaces = true;
                RestrictRealtime = true;
                RestrictSUIDSGID = true;
                SystemCallArchitectures = "native";
                UMask = "0077";
              };
            };

            networking.firewall.allowedUDPPorts = [ meshPort ];
          };
      };
  };
}
