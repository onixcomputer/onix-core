{
  self,
  pkgs,
  lib,
  ...
}:
let
  instanceName = "mesh-llm-private-inference";
  serviceName = "mesh-llm-${instanceName}";
  generatorName = serviceName;
  apiPort = 9337;
  consolePort = 3131;
  meshPort = 47916;
  proxyActivationModel = "Qwen3-0.6B-Q4_K_M";
  proxyActivationContextSize = 512;
  defaultMeshEndpointUrl = "http://127.0.0.1:13305/v1";
  desktopMeshEndpointUrl = "http://127.0.0.1:8000/v1";

  machineConfig = name: self.nixosConfigurations.${name}.config;
  mkNode =
    {
      label,
      machineName,
      meshAddress,
      endpointUrl,
      backendUnit,
    }:
    let
      config = machineConfig machineName;
      service = config.systemd.services.${serviceName};
    in
    {
      inherit
        label
        meshAddress
        endpointUrl
        backendUnit
        config
        service
        ;
      command = service.serviceConfig.ExecStart;
      credentials = service.serviceConfig.LoadCredential or [ ];
    };

  aspen1Node = mkNode {
    label = "Aspen1";
    machineName = "aspen1";
    meshAddress = "100.100.103.95";
    endpointUrl = defaultMeshEndpointUrl;
    backendUnit = "llamacpp-server-deepseek-v4-flash-aspen1.service";
  };
  aspen2Node = mkNode {
    label = "Aspen2";
    machineName = "aspen2";
    meshAddress = "100.125.64.121";
    endpointUrl = defaultMeshEndpointUrl;
    backendUnit = "lemonade.service";
  };
  aspen3Node = mkNode {
    label = "Aspen3";
    machineName = "aspen3";
    meshAddress = "100.108.13.4";
    endpointUrl = defaultMeshEndpointUrl;
    backendUnit = "lemonade.service";
  };
  desktopNode = mkNode {
    label = "Desktop";
    machineName = "britton-desktop";
    meshAddress = "100.110.43.11";
    endpointUrl = desktopMeshEndpointUrl;
    backendUnit = "qwen38-p150x2.service";
  };
  joinerNodes = [
    aspen2Node
    aspen3Node
    desktopNode
  ];
  meshNodes = [ aspen1Node ] ++ joinerNodes;
  desktopCommand = desktopNode.command;

  usesDedicatedUser = node: node.service.serviceConfig.User == "mesh-llm";
  hasPrivateLaunchFlags =
    node:
    lib.hasInfix "--mesh-discovery-mode mdns" node.command
    && lib.hasInfix "--headless" node.command
    && !(lib.hasInfix "--publish" node.command)
    && !(lib.hasInfix "--auto" node.command)
    && !(lib.hasInfix "--listen-all" node.command);
  selectsMeshAddress = node: lib.hasInfix node.meshAddress node.command;
  hasPluginAwareProxyActivation =
    node:
    lib.hasInfix "--model ${proxyActivationModel}" node.command
    && lib.hasInfix "--ctx-size ${toString proxyActivationContextSize}" node.command;
  deniesHostDevices = node: node.service.serviceConfig.PrivateDevices;
  ordersAfterBackend = node: builtins.elem node.backendUnit node.service.after;
  hasJoinCredential =
    node: lib.any (credential: lib.hasPrefix "join-token:" credential) node.credentials;
  hasJoinGenerator = node: builtins.hasAttr generatorName node.config.clan.core.vars.generators;
  tcpIsPrivate =
    node:
    !(builtins.elem apiPort node.config.networking.firewall.allowedTCPPorts)
    && !(builtins.elem consolePort node.config.networking.firewall.allowedTCPPorts);
  udpIsOpen = node: builtins.elem meshPort node.config.networking.firewall.allowedUDPPorts;

  plugins = self.packages.x86_64-linux.wasm-plugins;
  wasm = import ../lib/wasm.nix { inherit plugins; };
  serviceInventory = (wasm.evalNickelFile ../inventory/services/services.ncl).instances;
  desktopMeshSettings =
    serviceInventory.${instanceName}.roles.default.machines."britton-desktop".settings;
  desktopUsesQwenEndpoint =
    desktopMeshSettings.endpointUrl == desktopMeshEndpointUrl
    && desktopMeshSettings.backendUnit == desktopNode.backendUnit;
  meshSchema = wasm.evalNickelFile ../modules/mesh-llm/schema.ncl;
  dgxSparkTagName = "dgx-spark";
  dgxSparkBindInterface = "tailscale0";
  dgxSparkMeshInstanceName = "mesh-llm-dgx-spark";
  dgxSparkIrohInstanceName = "iroh-ssh-dgx-spark";
  tailscaleDgxTargetPresent = builtins.hasAttr dgxSparkTagName serviceInventory.br-tailnet.roles.peer.tags;
  irohDgxTargetPresent =
    builtins.hasAttr dgxSparkTagName
      serviceInventory.${dgxSparkIrohInstanceName}.roles.peer.tags;
  dgxSparkMeshRole = serviceInventory.${dgxSparkMeshInstanceName}.roles.default;
  meshDgxTargetPresent = builtins.hasAttr dgxSparkTagName dgxSparkMeshRole.tags;
  dgxSparkMeshSettings = dgxSparkMeshRole.settings;
  meshDgxUsesPrivateInterface =
    dgxSparkMeshSettings.mode == "joiner"
    && dgxSparkMeshSettings.endpointUrl == defaultMeshEndpointUrl
    && dgxSparkMeshSettings.meshBindInterface == dgxSparkBindInterface;
  meshDgxAvoidsExplicitWildcard = !(builtins.hasAttr "meshBindAddress" dgxSparkMeshSettings);

  dgxFixtureInstanceName = "dgx-fixture";
  dgxFixtureServiceName = "mesh-llm-${dgxFixtureInstanceName}";
  dgxFixtureSettings = {
    mode = "joiner";
    endpointUrl = defaultMeshEndpointUrl;
    inherit
      proxyActivationModel
      proxyActivationContextSize
      apiPort
      consolePort
      meshPort
      ;
    meshBindAddress = "0.0.0.0";
    meshBindInterface = dgxSparkBindInterface;
    meshName = "onix-private-inference";
    nodeName = null;
    backendUnit = null;
  };
  meshServiceDefinition = (import ../modules/mesh-llm { schema = meshSchema; }) { inherit lib; };
  mkDgxFixtureModuleConfig =
    resolvedSettings:
    let
      perInstance = meshServiceDefinition.roles.default.perInstance {
        instanceName = dgxFixtureInstanceName;
        extendSettings = _defaults: resolvedSettings;
      };
    in
    perInstance.nixosModule {
      inherit lib;
      pkgs = pkgs // {
        mesh-llm = meshPackage;
      };
      config = {
        networking.hostName = dgxFixtureInstanceName;
        clan.core.vars.generators.${dgxFixtureServiceName}.files."join-token".path =
          "/run/dgx-fixture-join-token";
      };
    };
  dgxFixtureModuleConfig = mkDgxFixtureModuleConfig dgxFixtureSettings;
  invalidDgxFixtureModuleConfig = mkDgxFixtureModuleConfig (
    dgxFixtureSettings
    // {
      meshBindInterface = null;
    }
  );
  dgxFixtureFailedAssertions = lib.filter (item: !item.assertion) dgxFixtureModuleConfig.assertions;
  dgxFixtureService = dgxFixtureModuleConfig.systemd.services.${dgxFixtureServiceName};
  dgxFixtureExecStart = dgxFixtureService.serviceConfig.ExecStart;
  dgxFixtureUsesTailscaleInterface =
    dgxFixtureFailedAssertions == [ ]
    && builtins.elem "tailscaled.service" dgxFixtureService.wants
    && builtins.elem "tailscaled.service" dgxFixtureService.after
    && dgxFixtureService.environment.MESH_LLM_BIND_INTERFACE == dgxSparkBindInterface;
  dgxFixtureRejectsMissingBinding = lib.any (
    item: !item.assertion && lib.hasInfix "set exactly one" item.message
  ) invalidDgxFixtureModuleConfig.assertions;

  meshPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.mesh-llm;
  armMeshPackage = self.packages.aarch64-linux.mesh-llm;
  armMeshTarget = "aarch64-unknown-linux-gnu";
  armMeshPackageSupported =
    armMeshPackage.releaseTarget == armMeshTarget
    && builtins.elem "aarch64-linux" armMeshPackage.meta.platforms
    && armMeshPackage ? openaiEndpoint;
  unsupportedDarwinExcluded = !(builtins.elem "aarch64-darwin" armMeshPackage.meta.platforms);
in
{
  checks = lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
    mesh-llm-sidecars =
      pkgs.runCommand "mesh-llm-sidecars" { nativeBuildInputs = [ pkgs.coreutils ]; }
        ''
          test -x ${meshPackage}/bin/mesh-llm
          test -x ${meshPackage}/bin/openai-endpoint
          test -f ${meshPackage}/share/mesh-llm/plugins/openai-endpoint/plugin.toml
          test -x ${dgxFixtureExecStart}
          grep -F 'mesh-llm-dgx-fixture-interface-launcher' ${dgxFixtureExecStart}

          ${lib.optionalString (!armMeshPackageSupported) ''
            echo "Mesh-LLM must select the pinned ARM64 Linux release and source-built plugin" >&2
            exit 1
          ''}
          ${lib.optionalString (!unsupportedDarwinExcluded) ''
            echo "Mesh-LLM must reject unsupported ARM64 Darwin packaging" >&2
            exit 1
          ''}
          ${lib.optionalString (!tailscaleDgxTargetPresent) ''
            echo "DGX Spark is missing the Tailscale service target" >&2
            exit 1
          ''}
          ${lib.optionalString (!irohDgxTargetPresent) ''
            echo "DGX Spark is missing the iroh-ssh service target" >&2
            exit 1
          ''}
          ${lib.optionalString (!meshDgxTargetPresent) ''
            echo "DGX Spark is missing the Mesh-LLM service target" >&2
            exit 1
          ''}
          ${lib.optionalString (!meshDgxUsesPrivateInterface) ''
            echo "DGX Spark Mesh-LLM must join through tailscale0" >&2
            exit 1
          ''}
          ${lib.optionalString (!meshDgxAvoidsExplicitWildcard) ''
            echo "DGX Spark Mesh-LLM must not declare a wildcard bind address" >&2
            exit 1
          ''}
          ${lib.optionalString (!dgxFixtureUsesTailscaleInterface) ''
            echo "DGX Spark Mesh-LLM interface fixture failed" >&2
            exit 1
          ''}
          ${lib.optionalString (!dgxFixtureRejectsMissingBinding) ''
            echo "Mesh-LLM accepted a fixture without a private bind target" >&2
            exit 1
          ''}

          grep -F -- '--mesh-discovery-mode mdns' ${aspen2Node.command}
          grep -F -- '--headless' ${aspen2Node.command}
          grep -F -- '--bind-ip ${aspen2Node.meshAddress}' ${aspen2Node.command}
          grep -F -- '--model ${proxyActivationModel}' ${aspen2Node.command}
          grep -F -- '--ctx-size ${toString proxyActivationContextSize}' ${aspen2Node.command}

          grep -F -- '--mesh-discovery-mode mdns' ${aspen3Node.command}
          grep -F -- '--headless' ${aspen3Node.command}
          grep -F -- '--bind-ip ${aspen3Node.meshAddress}' ${aspen3Node.command}
          grep -F -- '--model ${proxyActivationModel}' ${aspen3Node.command}
          grep -F -- '--ctx-size ${toString proxyActivationContextSize}' ${aspen3Node.command}

          grep -F -- '--mesh-discovery-mode mdns' ${desktopCommand}
          grep -F -- '--headless' ${desktopCommand}
          grep -F -- '--bind-ip ${desktopNode.meshAddress}' ${desktopCommand}
          grep -F -- '--model ${proxyActivationModel}' ${desktopCommand}
          grep -F -- '--ctx-size ${toString proxyActivationContextSize}' ${desktopCommand}

          ${lib.optionalString (!desktopUsesQwenEndpoint) ''
            echo "Desktop Mesh-LLM must target the Qwen endpoint and system unit" >&2
            exit 1
          ''}
          ${lib.optionalString (!(lib.all usesDedicatedUser meshNodes)) ''
            echo "Mesh-LLM services must use the dedicated unprivileged user" >&2
            exit 1
          ''}
          ${lib.optionalString (!(hasPrivateLaunchFlags aspen1Node)) ''
            echo "Aspen1 Mesh-LLM launch command must enforce private headless discovery" >&2
            exit 1
          ''}
          ${lib.optionalString (!(selectsMeshAddress aspen1Node)) ''
            echo "Aspen1 Mesh-LLM launch command must select its Tailscale address" >&2
            exit 1
          ''}
          ${lib.optionalString (!(hasPluginAwareProxyActivation aspen1Node)) ''
            echo "Mesh-LLM v0.72.2 sidecars must activate the plugin-aware proxy with a bounded CPU model" >&2
            exit 1
          ''}
          ${lib.optionalString (!(lib.all deniesHostDevices meshNodes)) ''
            echo "Mesh-LLM sidecars must not receive host GPU devices" >&2
            exit 1
          ''}
          ${lib.optionalString (!(lib.all ordersAfterBackend meshNodes)) ''
            echo "Mesh-LLM sidecars must start after their local inference backends" >&2
            exit 1
          ''}
          ${lib.optionalString (!(lib.all hasJoinCredential joinerNodes)) ''
            echo "Mesh-LLM joiners must load the join credential" >&2
            exit 1
          ''}
          ${lib.optionalString (!(lib.all hasJoinGenerator joinerNodes)) ''
            echo "Mesh-LLM join credential generators are absent" >&2
            exit 1
          ''}
          ${lib.optionalString (hasJoinGenerator aspen1Node) ''
            echo "Aspen1 seed must not require a join credential generator" >&2
            exit 1
          ''}
          ${lib.optionalString (!(lib.all tcpIsPrivate meshNodes)) ''
            echo "Mesh-LLM HTTP ports must remain absent from global firewall allowances" >&2
            exit 1
          ''}
          ${lib.optionalString (!(lib.all udpIsOpen meshNodes)) ''
            echo "Selected Mesh-LLM nodes must open the private mesh UDP port" >&2
            exit 1
          ''}

          missing_credentials="$TMPDIR/missing-credentials"
          mkdir -p "$missing_credentials"
          if CREDENTIALS_DIRECTORY="$missing_credentials" ${desktopCommand} >"$TMPDIR/missing.out" 2>"$TMPDIR/missing.err"; then
            echo "Desktop launcher accepted a missing join credential" >&2
            exit 1
          fi
          grep -F "join credential is missing" "$TMPDIR/missing.err"

          placeholder_credentials="$TMPDIR/placeholder-credentials"
          mkdir -p "$placeholder_credentials"
          printf '%s' 'Welcome to SOPS! Edit this file as you please!' > "$placeholder_credentials/join-token"
          if CREDENTIALS_DIRECTORY="$placeholder_credentials" ${desktopCommand} >"$TMPDIR/placeholder.out" 2>"$TMPDIR/placeholder.err"; then
            echo "Desktop launcher accepted the SOPS placeholder" >&2
            exit 1
          fi
          grep -F "join credential is unset" "$TMPDIR/placeholder.err"

          touch "$out"
        '';
  };
}
