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
  aspen1 = machineConfig "aspen1";
  desktop = machineConfig "britton-desktop";
  aspen2 = machineConfig "aspen2";
  aspen3 = machineConfig "aspen3";

  aspenService = aspen1.systemd.services.${serviceName};
  desktopService = desktop.systemd.services.${serviceName};
  aspenCommand = aspenService.serviceConfig.ExecStart;
  desktopCommand = desktopService.serviceConfig.ExecStart;
  desktopCredentials = desktopService.serviceConfig.LoadCredential;

  hasPrivateLaunchFlags =
    command:
    lib.hasInfix "--mesh-discovery-mode mdns" command
    && lib.hasInfix "--headless" command
    && !(lib.hasInfix "--publish" command)
    && !(lib.hasInfix "--auto" command)
    && !(lib.hasInfix "--listen-all" command);
  hasPluginAwareProxyActivation =
    command:
    lib.hasInfix "--model ${proxyActivationModel}" command
    && lib.hasInfix "--ctx-size ${toString proxyActivationContextSize}" command;

  hasJoinCredential = lib.any (credential: lib.hasPrefix "join-token:" credential) desktopCredentials;
  tcpIsPrivate =
    config:
    !(builtins.elem apiPort config.networking.firewall.allowedTCPPorts)
    && !(builtins.elem consolePort config.networking.firewall.allowedTCPPorts);
  udpIsOpen = config: builtins.elem meshPort config.networking.firewall.allowedUDPPorts;
  serviceAbsent = config: !(builtins.hasAttr serviceName config.systemd.services);
  generatorAbsent = config: !(builtins.hasAttr generatorName config.clan.core.vars.generators);

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
          grep -F -- '--model ${proxyActivationModel}' ${desktopCommand}
          grep -F -- '--ctx-size ${toString proxyActivationContextSize}' ${desktopCommand}

          ${lib.optionalString (aspenService.serviceConfig.User != "mesh-llm") ''
            echo "Aspen1 Mesh-LLM service must use the dedicated unprivileged user" >&2
            exit 1
          ''}
          ${lib.optionalString (desktopService.serviceConfig.User != "mesh-llm") ''
            echo "Desktop Mesh-LLM service must use the dedicated unprivileged user" >&2
            exit 1
          ''}
          ${lib.optionalString (!hasPrivateLaunchFlags aspenCommand) ''
            echo "Aspen1 launch command does not enforce private headless discovery" >&2
            exit 1
          ''}
          ${lib.optionalString (!(lib.hasInfix "100.100.103.95" aspenCommand)) ''
            echo "Aspen1 launch command does not select its Tailscale address" >&2
            exit 1
          ''}
          ${lib.optionalString (!(hasPluginAwareProxyActivation aspenCommand)) ''
            echo "Mesh-LLM v0.72.2 sidecars must activate the plugin-aware proxy with a bounded CPU model" >&2
            exit 1
          ''}
          ${lib.optionalString
            (!(aspenService.serviceConfig.PrivateDevices && desktopService.serviceConfig.PrivateDevices))
            ''
              echo "Mesh-LLM sidecars must not receive host GPU devices" >&2
              exit 1
            ''
          }
          ${lib.optionalString (!hasJoinCredential) ''
            echo "Desktop Mesh-LLM service does not load the join credential" >&2
            exit 1
          ''}
          ${lib.optionalString (!(builtins.hasAttr generatorName desktop.clan.core.vars.generators)) ''
            echo "Desktop Mesh-LLM join credential generator is absent" >&2
            exit 1
          ''}
          ${lib.optionalString (!generatorAbsent aspen1) ''
            echo "Aspen1 seed must not require a join credential generator" >&2
            exit 1
          ''}
          ${lib.optionalString (!(tcpIsPrivate aspen1 && tcpIsPrivate desktop)) ''
            echo "Mesh-LLM HTTP ports must remain absent from global firewall allowances" >&2
            exit 1
          ''}
          ${lib.optionalString (!(udpIsOpen aspen1 && udpIsOpen desktop)) ''
            echo "Selected Mesh-LLM nodes must open the private mesh UDP port" >&2
            exit 1
          ''}
          ${lib.optionalString (!(serviceAbsent aspen2 && serviceAbsent aspen3)) ''
            echo "Aspen2 and Aspen3 must not receive Mesh-LLM sidecars" >&2
            exit 1
          ''}
          ${lib.optionalString (!(generatorAbsent aspen2 && generatorAbsent aspen3)) ''
            echo "Aspen2 and Aspen3 must not receive Mesh-LLM credentials" >&2
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
