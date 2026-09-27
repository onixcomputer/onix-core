{
  config,
  pkgs,
  lib,
  instanceName,
  settings,
  # Invite tokens in join order: [ { name = <credential name>; path = <runtime secret path>; } ].
  joinTokens ? [ ],
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
  dynamicJoinTokenFilePlaceholder = name: "__mesh_join_token_file_${name}__";
  joinCredentialNames = map (token: token.name) joinTokens;
  hasStaticMeshBindAddress = !(builtins.elem meshBindAddress wildcardMeshBindAddresses);
  hasMeshBindInterface = meshBindInterface != null && meshBindInterface != "";
  effectiveMeshBindAddress =
    if hasMeshBindInterface then dynamicMeshBindAddressPlaceholder else meshBindAddress;
  effectiveJoinTokenFiles = map (
    name: if hasMeshBindInterface then dynamicJoinTokenFilePlaceholder name else "%d/${name}"
  ) joinCredentialNames;
  effectiveNodeName =
    if nodeName == null || nodeName == "" then config.networking.hostName else nodeName;

  extraEndpoints = settings.extraEndpoints or { };
  researchEnabled = settings.researchMode != "disabled";
  researchConfigFile = pkgs.writeText "${serviceName}-research.json" (
    builtins.toJSON (
      {
        mode = settings.researchMode;
      }
      // (
        if settings.researchMode == "provider" then
          {
            arxiv = settings.researchArxivAddress;
            laya = settings.researchLayaAddress;
          }
        else
          { target_peer = settings.researchTargetPeer; }
      )
    )
  );
  researchGatewayName = "${serviceName}-research-http";
  researchGatewayEnabled = settings.researchHttpBindAddress != null;
  researchGatewayConfig = pkgs.writeText "${researchGatewayName}.conf" ''
    daemon off;
    worker_processes 1;
    pid /run/${researchGatewayName}/nginx.pid;
    error_log stderr warn;
    events { worker_connections 64; }
    http {
      access_log off;
      client_body_temp_path /run/${researchGatewayName}/client_body;
      proxy_temp_path /run/${researchGatewayName}/proxy;
      server {
        listen ${settings.researchHttpBindAddress}:${toString settings.researchHttpPort};
        client_max_body_size 32k;
        proxy_http_version 1.1;
        proxy_set_header Connection close;
        proxy_set_header Host 127.0.0.1;
        proxy_read_timeout 95s;
        proxy_send_timeout 95s;
        proxy_buffering off;
        ${lib.concatMapStringsSep "\n"
          (path: ''
            location = /${path} {
              limit_except POST { deny all; }
              proxy_pass http://127.0.0.1:${toString consolePort}/api/plugins/research/http/${path};
            }
          '')
          [
            "search"
            "paper"
            "predict"
          ]
        }
        location / { return 404; }
      }
    }
  '';
  endpointUrls = {
    "openai-endpoint" = endpointUrl;
  }
  // extraEndpoints;
  configFile = pkgs.writeText "${serviceName}-config.toml" (
    "version = 1\n\n"
    + lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: url: ''
        [[plugin]]
        name = ${builtins.toJSON name}
        command = "${package}/bin/openai-endpoint"
        url = ${builtins.toJSON url}
      '') endpointUrls
    )
    + lib.optionalString researchEnabled ''
      [[plugin]]
      name = "research"
      command = "${pkgs.mesh-research}/bin/onix-mesh-research"
      args = [${builtins.toJSON (toString researchConfigFile)}]
    ''
  );

  launchArgs = mkLaunchArgs {
    inherit package settings;
    configPath = configFile;
    nodeName = effectiveNodeName;
    meshBindAddress = effectiveMeshBindAddress;
    joinTokenFiles = effectiveJoinTokenFiles;
  };
  launchCommandTemplate = lib.escapeShellArgs launchArgs;
  interfaceLauncherPlaceholders = [
    (lib.escapeShellArg dynamicMeshBindAddressPlaceholder)
  ]
  ++ map (name: lib.escapeShellArg (dynamicJoinTokenFilePlaceholder name)) joinCredentialNames;
  interfaceLauncherValues = [
    ''"$mesh_bind_address"''
  ]
  ++ map (name: ''"$credentials_directory"/${lib.escapeShellArg name}'') joinCredentialNames;
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
          ${lib.optionalString (joinTokens != [ ]) ''
            credentials_directory="''${CREDENTIALS_DIRECTORY:?systemd credentials are unavailable}"
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
  researchBackendUnits = lib.optionals (
    settings.researchMode == "provider"
  ) settings.researchBackendUnits;
  backendOwned = backendUnits != [ ] || backendExternallyManaged;
  restartDelay = "10s";
  stopTimeout = "30s";

  # mesh-llm 0.72.2 on britton-desktop once dropped its API listener while the process
  # kept running (2026-09-27): the console answered, 127.0.0.1:apiPort refused every
  # connection, and systemd saw nothing wrong. The watchdog restarts the sidecar after
  # consecutive refused checks. A sidecar that is not active, or that started less than
  # the grace period ago (the API binds about two minutes after start), is left alone.
  watchdogName = "${serviceName}-api-watchdog";
  watchdogStartupGraceSeconds = 300;
  watchdogFailureLimit = 3;
  watchdogScript = pkgs.writeShellApplication {
    name = watchdogName;
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      unit=${serviceName}.service
      failures_file=/run/${watchdogName}/failures
      if [ "$(systemctl show -p ActiveState --value "$unit")" != active ]; then
        rm -f "$failures_file"
        exit 0
      fi
      read -r uptime _ < /proc/uptime
      started=$(( $(systemctl show -p ActiveEnterTimestampMonotonic --value "$unit") / 1000000 ))
      if [ $(( ''${uptime%.*} - started )) -lt ${toString watchdogStartupGraceSeconds} ]; then
        exit 0
      fi
      if timeout 5 bash -c 'exec 3<>/dev/tcp/127.0.0.1/${toString apiPort}' 2>/dev/null; then
        rm -f "$failures_file"
        exit 0
      fi
      failures=$(( $(cat "$failures_file" 2>/dev/null || echo 0) + 1 ))
      if [ "$failures" -lt ${toString watchdogFailureLimit} ]; then
        echo "$failures" > "$failures_file"
        echo "API listener 127.0.0.1:${toString apiPort} refused a connection ($failures/${toString watchdogFailureLimit})"
        exit 0
      fi
      rm -f "$failures_file"
      echo "API listener 127.0.0.1:${toString apiPort} refused ${toString watchdogFailureLimit} checks in a row; restarting $unit"
      systemctl restart "$unit"
    '';
  };
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
      assertion = lib.all (
        url: builtins.isString url && lib.hasPrefix "http://127.0.0.1:" url && lib.hasSuffix "/v1" url
      ) (builtins.attrValues endpointUrls);
      message = "${serviceName}: all endpoints must be loopback OpenAI-compatible /v1 endpoints.";
    }
    {
      assertion = !(extraEndpoints ? "openai-endpoint");
      message = "${serviceName}: extraEndpoints must not replace the primary openai-endpoint.";
    }
    {
      assertion = !(extraEndpoints ? research);
      message = "${serviceName}: the research plugin name is reserved for native research operations.";
    }
    {
      assertion =
        settings.researchMode != "provider"
        || settings.researchArxivAddress != null
        || settings.researchLayaAddress != null;
      message = "${serviceName}: a research provider requires at least one configured backend.";
    }
    {
      assertion =
        settings.researchMode != "forwarder"
        || builtins.match "^[0-9a-f]{64}$" settings.researchTargetPeer != null;
      message = "${serviceName}: a research forwarder requires the provider's full lowercase peer ID.";
    }
    {
      assertion =
        !researchGatewayEnabled
        || (
          researchEnabled
          &&
            builtins.match "^100\\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\\.[0-9]+\\.[0-9]+$" settings.researchHttpBindAddress
            != null
          && !(builtins.elem settings.researchHttpPort [
            apiPort
            consolePort
            meshPort
          ])
        );
      message = "${serviceName}: research HTTP ingress requires an enabled plugin, a Tailscale bind address, and a distinct port.";
    }
    {
      assertion = backendOwned;
      message = "${serviceName}: a loopback backend requires backendUnit or explicit external ownership.";
    }
    {
      assertion = !isJoiner || joinTokens != [ ];
      message = "${serviceName}: joiner mode requires at least one runtime invite token path.";
    }
    {
      assertion = isJoiner || joinTokens == [ ];
      message = "${serviceName}: a seed originates the mesh ID and must not receive invite tokens.";
    }
    {
      assertion =
        lib.all (
          token: token.path != "" && builtins.match "^[a-zA-Z0-9_.-]+$" token.name != null
        ) joinTokens
        && lib.length (lib.unique joinCredentialNames) == lib.length joinCredentialNames;
      message = "${serviceName}: invite tokens need distinct credential names and non-empty paths.";
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
    wants = [ "network-online.target" ] ++ interfaceUnits ++ backendUnits ++ researchBackendUnits;
    after = [ "network-online.target" ] ++ interfaceUnits ++ backendUnits ++ researchBackendUnits;

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
      LoadCredential = map (token: "${token.name}:${token.path}") joinTokens;
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

  systemd.services.${watchdogName} = {
    description = "Restart ${serviceName} when its API listener disappears";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe watchdogScript;
      RuntimeDirectory = watchdogName;
      RuntimeDirectoryPreserve = "yes";
    };
  };

  systemd.timers.${watchdogName} = {
    description = "Check the ${serviceName} API listener every minute";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "1min";
      AccuracySec = "10s";
    };
  };

  systemd.services.${researchGatewayName} = lib.mkIf researchGatewayEnabled {
    description = "Private research-only Mesh-LLM HTTP ingress (${instanceName})";
    wantedBy = [ "multi-user.target" ];
    wants = [
      "tailscaled.service"
      "${serviceName}.service"
    ];
    after = [
      "tailscaled.service"
      "${serviceName}.service"
    ];
    serviceConfig = {
      ExecStart = "${pkgs.nginx}/bin/nginx -c ${researchGatewayConfig} -p /run/${researchGatewayName}";
      DynamicUser = true;
      RuntimeDirectory = researchGatewayName;
      Restart = "on-failure";
      RestartSec = "5s";
      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_UNIX"
      ];
      CapabilityBoundingSet = "";
      UMask = "0077";
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts =
    lib.optional researchGatewayEnabled settings.researchHttpPort;

  networking.firewall.allowedUDPPorts = [ meshPort ];
}
