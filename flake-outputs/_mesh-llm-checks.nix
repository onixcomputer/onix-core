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
    backendUnit = "lemonade.service";
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

  meshPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.mesh-llm;
in
{
  checks = lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") {
    mesh-llm-sidecars =
      pkgs.runCommand "mesh-llm-sidecars" { nativeBuildInputs = [ pkgs.coreutils ]; }
        ''
          test -x ${meshPackage}/bin/mesh-llm
          test -x ${meshPackage}/bin/openai-endpoint
          test -f ${meshPackage}/share/mesh-llm/plugins/openai-endpoint/plugin.toml
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
