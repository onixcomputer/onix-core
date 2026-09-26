{ settings }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  files = config.clan.core.vars.generators.underclass.files;
  remoteHost = settings.ompUnderclassRemoteHost;
  isRemote = remoteHost != "";
  meshGateway = settings.underclassMeshGateway;
  enabled = settings.ompUnderclass || isRemote || meshGateway;
  remoteProxyKey = "/run/secrets/vars/per-machine/${remoteHost}/underclass/proxy-key";
  clientSecret = {
    secret = true;
    deploy = true;
    owner = settings.ompUnderclassUser;
    mode = "0400";
  };
  providerConfig = pkgs.writeText "omp-underclass-provider.json" (
    builtins.toJSON {
      baseUrl = "http://127.0.0.1:8080/v1";
      apiKey =
        if isRemote then
          "!${pkgs.openssh}/bin/ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=5 ${lib.escapeShellArg remoteHost} ${pkgs.coreutils}/bin/cat ${lib.escapeShellArg remoteProxyKey}"
        else
          "!${pkgs.coreutils}/bin/cat ${lib.escapeShellArg files."proxy-key".path}";
    }
  );
  extension = pkgs.runCommand "omp-underclass-provider" { } ''
    mkdir -p "$out"
    cp ${./underclass.ts} "$out/index.ts"
    cp ${providerConfig} "$out/provider.json"
  '';
  gateway = pkgs.callPackage ../../pkgs/underclass-mesh-gateway { };
in
{
  # r[impl onix.underclass.scope]
  config = lib.mkIf enabled {
    assertions = [
      {
        assertion = builtins.elem "omp" settings.packages;
        message = "llm-agents: Underclass provider requires omp in the instance's packages.";
      }
      {
        assertion = !(settings.ompUnderclass && isRemote);
        message = "llm-agents: choose local ompUnderclass or ompUnderclassRemoteHost, not both.";
      }
      # r[impl onix.underclass.mesh.isolation]
      {
        assertion = !meshGateway || settings.ompUnderclass;
        message = "llm-agents: underclassMeshGateway serves only a local ompUnderclass pool.";
      }
    ];

    # r[impl onix.underclass.secrets]
    # Each machine owns its OAuth pool; never copy rotating refresh tokens
    # between Underclass and OMP or between machines.
    clan.core.vars.generators.underclass = lib.mkIf settings.ompUnderclass {
      files = {
        "proxy-key" = clientSecret;
        "ui-token" = clientSecret;
        "env-file" = {
          secret = true;
          deploy = true;
          owner = "root";
          group = "root";
          mode = "0400";
        };
      };
      runtimeInputs = [ pkgs.openssl ];
      script = ''
        proxy_key="$(openssl rand -hex 32)"
        ui_token="$(openssl rand -hex 32)"
        printf '%s\n' "$proxy_key" > "$out/proxy-key"
        printf '%s\n' "$ui_token" > "$out/ui-token"
        printf 'UNDERCLASS_PROXY_KEY=%s\nUNDERCLASS_UI_TOKEN=%s\n' \
          "$proxy_key" "$ui_token" > "$out/env-file"
      '';
    };

    # r[impl onix.underclass.local-service]
    services.underclass = lib.mkIf settings.ompUnderclass {
      enable = true;
      bindAddress = "127.0.0.1:8080";
      openFirewall = false;
      environmentFile = files."env-file".path;
      # Banked reset credits are user-controlled, not spent automatically.
      settings.auto_codex_resets = false;
    };

    # r[impl onix.underclass.mesh.gateway]
    # Mesh-LLM probes and forwards endpoints without credentials, and Codex
    # accepts only streamed Responses requests. This loopback gateway holds the
    # proxy key and serves the pool as chat completions. PartOf lets the
    # documented underclass.service restart after key rotation refresh it too.
    systemd.services.underclass-mesh-gateway = lib.mkIf meshGateway {
      description = "Loopback Underclass gateway for Mesh-LLM";
      wantedBy = [ "multi-user.target" ];
      wants = [ "underclass.service" ];
      after = [ "underclass.service" ];
      partOf = [ "underclass.service" ];
      serviceConfig = {
        ExecStart = lib.escapeShellArgs [
          (lib.getExe gateway)
          "--listen"
          "127.0.0.1:${toString settings.underclassMeshPort}"
          "--upstream"
          "http://${config.services.underclass.bindAddress}/v1"
          "--key-file"
          "%d/proxy-key"
        ];
        LoadCredential = [ "proxy-key:${files."proxy-key".path}" ];
        DynamicUser = true;
        Restart = "on-failure";
        RestartSec = "5s";
        CapabilityBoundingSet = "";
        IPAddressAllow = "localhost";
        IPAddressDeny = "any";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
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
        RestrictAddressFamilies = [ "AF_INET" ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        UMask = "0077";
      };
    };

    # r[impl onix.underclass.omp]
    system.build.omp-underclass = extension;
    home-manager.users.${settings.ompUnderclassUser} = {
      home.file.".omp/agent/extensions/underclass".source = extension;

      # The local OMP client shares the remote pool, but its OAuth tokens stay
      # with the remote service. SSH also resolves the scoped proxy key.
      systemd.user.services.underclass-ssh-tunnel = lib.mkIf isRemote {
        Unit = {
          Description = "SSH tunnel to ${remoteHost} Underclass pool";
          After = [ "network-online.target" ];
          Wants = [ "network-online.target" ];
        };
        Service = {
          Type = "simple";
          ExecStart = "${pkgs.openssh}/bin/ssh -T -N -o BatchMode=yes -o StrictHostKeyChecking=yes -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -L 127.0.0.1:8080:127.0.0.1:8080 ${lib.escapeShellArg remoteHost}";
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
  };
}
