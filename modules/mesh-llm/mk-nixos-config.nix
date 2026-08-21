{
  config,
  pkgs,
  lib,
  instanceName,
  settings,
  joinTokenPath ? null,
  package ? pkgs.mesh-llm,
}:
let
  mkLaunchArgs = import ./mk-launch-args.nix { inherit lib; };

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
    backendExternallyManaged
    ;

  isJoiner = mode == "joiner";
  serviceName = "mesh-llm-${instanceName}";
  serviceUser = "mesh-llm";
  stateDirectory = serviceName;
  statePath = "/var/lib/${stateDirectory}";
  wildcardMeshBindAddresses = [
    "0.0.0.0"
    "::"
  ];
  dynamicMeshBindAddressPlaceholder = "__mesh_bind_address__";
  dynamicJoinTokenFilePlaceholder = "__mesh_join_token_file__";
  joinCredentialName = "join-token";
  systemdJoinTokenFile = "%d/${joinCredentialName}";
  hasStaticMeshBindAddress = !(builtins.elem meshBindAddress wildcardMeshBindAddresses);
  hasMeshBindInterface = meshBindInterface != null && meshBindInterface != "";
  effectiveMeshBindAddress =
    if hasMeshBindInterface then dynamicMeshBindAddressPlaceholder else meshBindAddress;
  effectiveJoinTokenFile =
    if isJoiner then
      if hasMeshBindInterface then dynamicJoinTokenFilePlaceholder else systemdJoinTokenFile
    else
      null;
  effectiveNodeName =
    if nodeName == null || nodeName == "" then config.networking.hostName else nodeName;

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
    joinTokenFile = effectiveJoinTokenFile;
  };
  launchCommandTemplate = lib.escapeShellArgs launchArgs;
  interfaceLauncherPlaceholders = [
    (lib.escapeShellArg dynamicMeshBindAddressPlaceholder)
  ]
  ++ lib.optionals isJoiner [ (lib.escapeShellArg dynamicJoinTokenFilePlaceholder) ];
  interfaceLauncherValues = [
    ''"$mesh_bind_address"''
  ]
  ++ lib.optionals isJoiner [ ''"$join_token_file"'' ];
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
          ${lib.optionalString isJoiner ''
            join_token_file="''${CREDENTIALS_DIRECTORY:?systemd credentials are unavailable}/${joinCredentialName}"
          ''}
          exec ${
            lib.replaceStrings interfaceLauncherPlaceholders interfaceLauncherValues launchCommandTemplate
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

  minimumProxyActivationContextSize = 512;

  interfaceUnits = lib.optional (meshBindInterface == "tailscale0") "tailscaled.service";
  backendUnits = lib.optional (backendUnit != null && backendUnit != "") backendUnit;
  backendOwned = backendUnits != [ ] || backendExternallyManaged;
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
      assertion = backendOwned;
      message = "${serviceName}: a loopback backend requires backendUnit or explicit external ownership.";
    }
    {
      assertion = !isJoiner || (joinTokenPath != null && joinTokenPath != "");
      message = "${serviceName}: joiner mode requires a runtime join-token path.";
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
      ExecStart = launchCommand;
      LoadCredential = lib.optionals isJoiner [ "${joinCredentialName}:${joinTokenPath}" ];
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
}
