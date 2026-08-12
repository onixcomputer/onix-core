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
  meshEndpointUrl = "http://127.0.0.1:13305/v1";

  machineConfig = name: self.nixosConfigurations.${name}.config;
  mkNode =
    {
      label,
      machineName,
      meshAddress,
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
    backendUnit = "llamacpp-server-deepseek-v4-flash-aspen1.service";
  };
  aspen2Node = mkNode {
    label = "Aspen2";
    machineName = "aspen2";
    meshAddress = "100.125.64.121";
    backendUnit = "lemonade.service";
  };
  aspen3Node = mkNode {
    label = "Aspen3";
    machineName = "aspen3";
    meshAddress = "100.108.13.4";
    backendUnit = "lemonade.service";
  };
  desktopNode = mkNode {
    label = "Desktop";
    machineName = "britton-desktop";
    meshAddress = "100.110.43.11";
    backendUnit = "llamacpp-server-vibethinker-britton-desktop.service";
  };
  joinerNodes = [
    aspen2Node
    aspen3Node
    desktopNode
  ];
  meshNodes = [ aspen1Node ] ++ joinerNodes;

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
  hasJoinFileArgument =
    node: lib.hasInfix "--join-file" node.command && lib.hasInfix "%d/join-token" node.command;
  hasJoinGenerator = node: builtins.hasAttr generatorName node.config.clan.core.vars.generators;
  tcpIsPrivate =
    node:
    !(builtins.elem apiPort node.config.networking.firewall.allowedTCPPorts)
    && !(builtins.elem consolePort node.config.networking.firewall.allowedTCPPorts);
  udpIsOpen = node: builtins.elem meshPort node.config.networking.firewall.allowedUDPPorts;

  plugins = self.packages.x86_64-linux.wasm-plugins;
  wasm = import ../lib/wasm.nix { inherit plugins; };
  meshSchema = wasm.evalNickelFile ../modules/mesh-llm/schema.ncl;
  dgxSparkBindInterface = "tailscale0";
  dgxFixtureInstanceName = "dgx-fixture";
  dgxFixtureServiceName = "mesh-llm-${dgxFixtureInstanceName}";
  dgxFixtureBackendUnit = "fixture-openai-backend.service";
  dgxFixtureJoinTokenPath = "/run/dgx-fixture-join-token";
  dgxFixtureSettings = {
    mode = "joiner";
    endpointUrl = meshEndpointUrl;
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
    backendUnit = dgxFixtureBackendUnit;
    backendExternallyManaged = false;
  };
  dgxFixtureConfig = {
    networking.hostName = dgxFixtureInstanceName;
    clan.core.vars.generators.${dgxFixtureServiceName}.files."join-token".path =
      dgxFixtureJoinTokenPath;
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
      config = dgxFixtureConfig;
    };
  dgxFixtureModuleMerge = mkDgxFixtureModuleConfig dgxFixtureSettings;
  dgxFixtureModuleConfig =
    assert dgxFixtureModuleMerge._type == "merge";
    builtins.head dgxFixtureModuleMerge.contents;
  directDgxFixtureModuleConfig = import ../modules/mesh-llm/mk-nixos-config.nix {
    inherit lib pkgs;
    config = dgxFixtureConfig;
    instanceName = dgxFixtureInstanceName;
    settings = dgxFixtureSettings;
    joinTokenPath = dgxFixtureJoinTokenPath;
    package = meshPackage;
  };
  invalidDgxFixtureModuleMerge = mkDgxFixtureModuleConfig (
    dgxFixtureSettings
    // {
      meshBindInterface = null;
    }
  );
  invalidDgxFixtureModuleConfig =
    assert invalidDgxFixtureModuleMerge._type == "merge";
    builtins.head invalidDgxFixtureModuleMerge.contents;
  invalidDgxBackendModuleMerge = mkDgxFixtureModuleConfig (
    dgxFixtureSettings
    // {
      backendUnit = null;
    }
  );
  invalidDgxBackendModuleConfig =
    assert invalidDgxBackendModuleMerge._type == "merge";
    builtins.head invalidDgxBackendModuleMerge.contents;
  dgxFixtureFailedAssertions = lib.filter (item: !item.assertion) dgxFixtureModuleConfig.assertions;
  dgxFixtureService = dgxFixtureModuleConfig.systemd.services.${dgxFixtureServiceName};
  dgxFixtureExecStart = dgxFixtureService.serviceConfig.ExecStart;
  dgxFixtureUsesExpectedLauncher = lib.hasInfix "mesh-llm-dgx-fixture-interface-launcher" dgxFixtureExecStart;
  dgxFixtureUsesTailscaleInterface =
    dgxFixtureFailedAssertions == [ ]
    && builtins.elem "tailscaled.service" dgxFixtureService.wants
    && builtins.elem "tailscaled.service" dgxFixtureService.after
    && dgxFixtureService.environment.MESH_LLM_BIND_INTERFACE == dgxSparkBindInterface;
  dgxFixtureCoreParity =
    dgxFixtureModuleConfig.systemd.services.${dgxFixtureServiceName}
    == directDgxFixtureModuleConfig.systemd.services.${dgxFixtureServiceName}
    &&
      dgxFixtureModuleConfig.networking.firewall.allowedUDPPorts
      == directDgxFixtureModuleConfig.networking.firewall.allowedUDPPorts;
  dgxFixtureRejectsMissingBinding = lib.any (
    item: !item.assertion && lib.hasInfix "set exactly one" item.message
  ) invalidDgxFixtureModuleConfig.assertions;
  dgxFixtureRejectsMissingBackend = lib.any (
    item: !item.assertion && lib.hasInfix "requires backendUnit" item.message
  ) invalidDgxBackendModuleConfig.assertions;

  meshPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.mesh-llm;
  armMeshPackage = self.packages.aarch64-linux.mesh-llm;
  armMeshTarget = "aarch64-unknown-linux-gnu";
  expectedLlamaRevision = "86b94708f22478f900b76ca02e316f4f3418faff";
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
          test ${lib.escapeShellArg meshPackage.llamaRevision} = ${lib.escapeShellArg expectedLlamaRevision}
          ${meshPackage}/bin/mesh-llm --help > "$TMPDIR/help"
          grep -F -- '--join-file <PATH>' "$TMPDIR/help"
          test -x ${dgxFixtureExecStart}
          grep -F -- '--join-file "$join_token_file"' ${dgxFixtureExecStart}
          grep -F 'CREDENTIALS_DIRECTORY' ${dgxFixtureExecStart}

          ${lib.optionalString (!armMeshPackageSupported) ''
            echo "Mesh-LLM must select the pinned ARM64 Linux release and source-built plugin" >&2
            exit 1
          ''}
          ${lib.optionalString (!unsupportedDarwinExcluded) ''
            echo "Mesh-LLM must reject unsupported ARM64 Darwin packaging" >&2
            exit 1
          ''}
          ${lib.optionalString (!dgxFixtureUsesExpectedLauncher) ''
            echo "DGX Spark Mesh-LLM did not select its interface launcher" >&2
            exit 1
          ''}
          ${lib.optionalString (!dgxFixtureUsesTailscaleInterface) ''
            echo "DGX Spark Mesh-LLM interface fixture failed" >&2
            exit 1
          ''}
          ${lib.optionalString (!dgxFixtureCoreParity) ''
            echo "Mesh-LLM Clan and plain NixOS cores diverged" >&2
            exit 1
          ''}
          ${lib.optionalString (!dgxFixtureRejectsMissingBinding) ''
            echo "Mesh-LLM accepted a fixture without a private bind target" >&2
            exit 1
          ''}
          ${lib.optionalString (!dgxFixtureRejectsMissingBackend) ''
            echo "Mesh-LLM accepted an unowned loopback backend" >&2
            exit 1
          ''}

          ${lib.optionalString (!(lib.all usesDedicatedUser meshNodes)) ''
            echo "Mesh-LLM services must use the dedicated unprivileged user" >&2
            exit 1
          ''}
          ${lib.optionalString (!(lib.all hasPrivateLaunchFlags meshNodes)) ''
            echo "Mesh-LLM launch commands must enforce private headless discovery" >&2
            exit 1
          ''}
          ${lib.optionalString (!(lib.all selectsMeshAddress meshNodes)) ''
            echo "Mesh-LLM launch commands must select each Tailscale address" >&2
            exit 1
          ''}
          ${lib.optionalString (!(lib.all hasPluginAwareProxyActivation meshNodes)) ''
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
          ${lib.optionalString (!(lib.all hasJoinFileArgument joinerNodes)) ''
            echo "Mesh-LLM joiners must pass only the systemd credential path" >&2
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
          ${lib.optionalString (lib.hasInfix "--join-file" aspen1Node.command) ''
            echo "Aspen1 seed must not receive a join credential file" >&2
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

          if ${meshPackage}/bin/mesh-llm --join-file "$TMPDIR/missing-token" serve --headless >"$TMPDIR/missing.out" 2>"$TMPDIR/missing.err"; then
            echo "Mesh-LLM accepted a missing join credential file" >&2
            exit 1
          fi
          grep -F "failed to read join token file" "$TMPDIR/missing.err"

          : > "$TMPDIR/empty-token"
          if ${meshPackage}/bin/mesh-llm --join-file "$TMPDIR/empty-token" serve --headless >"$TMPDIR/empty.out" 2>"$TMPDIR/empty.err"; then
            echo "Mesh-LLM accepted an empty join credential file" >&2
            exit 1
          fi
          grep -F "file contains no token" "$TMPDIR/empty.err"

          printf '%s\n%s\n' first second > "$TMPDIR/multiline-token"
          if ${meshPackage}/bin/mesh-llm --join-file "$TMPDIR/multiline-token" serve --headless >"$TMPDIR/multiline.out" 2>"$TMPDIR/multiline.err"; then
            echo "Mesh-LLM accepted a multiline join credential file" >&2
            exit 1
          fi
          grep -F "token contains whitespace" "$TMPDIR/multiline.err"
          if grep -F first "$TMPDIR/multiline.err"; then
            echo "Mesh-LLM logged join credential contents" >&2
            exit 1
          fi

          printf 'token\n\n' > "$TMPDIR/extra-newline-token"
          if ${meshPackage}/bin/mesh-llm --join-file "$TMPDIR/extra-newline-token" serve --headless >"$TMPDIR/extra-newline.out" 2>"$TMPDIR/extra-newline.err"; then
            echo "Mesh-LLM accepted extra credential lines" >&2
            exit 1
          fi
          grep -F "token contains whitespace" "$TMPDIR/extra-newline.err"

          touch "$out"
        '';
  };
}
