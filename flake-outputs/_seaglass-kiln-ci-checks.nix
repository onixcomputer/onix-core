{
  self,
  pkgs,
  lib,
  ...
}:
let
  desktopConfig = self.nixosConfigurations.britton-desktop.config;
  brokerSettings = desktopConfig.services.radicle.ci.broker.settings;
  brokerServiceConfig = desktopConfig.systemd.services.radicle-ci-broker.serviceConfig;
  replicationService = desktopConfig.systemd.services.radicle-seaglass-replicate;
  replicationServiceConfig = replicationService.serviceConfig;
  replicationCommand = replicationServiceConfig.ExecStart;
  reportServerName = "radicle-ci-reports";
  reportServer = desktopConfig.systemd.services.${reportServerName};
  reportServerConfig = reportServer.serviceConfig;
  reportServerCommand = reportServerConfig.ExecStart;
  reportHttpConfig = desktopConfig.services.traefik.dynamicConfigOptions.http;
  reportRouter = reportHttpConfig.routers.${reportServerName};
  reportBackend = reportHttpConfig.services.${reportServerName};
  reportStripPrefixMiddlewareName = "${reportServerName}-strip-prefix";
  reportTailnetMiddlewareName = "${reportServerName}-tailnet-only";
  reportStripPrefixMiddleware = reportHttpConfig.middlewares.${reportStripPrefixMiddlewareName};
  reportTailnetMiddleware = reportHttpConfig.middlewares.${reportTailnetMiddlewareName};
  ddclientPrivateCommand = desktopConfig.systemd.services.ddclient-private.serviceConfig.ExecStart;
  seaglassRid = "rad:z3xXXCQXCTquvAawh41YYs8yC8xmk";
  seaglassRevision = "44ed329b09e472aa12866c8dceedbfb3526b25a1";
  seaglassIdentityRevision = "34622578746c320714509e309233fc7df051d202";
  personalNodeId = "z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx";
  privatePilotRid = "rad:z3t9ykR1HfG9UkyKoQQg5ikkzrTxg";
  expectedMaxRunTime = "2h";
  expectedKilnPath = lib.makeBinPath [
    pkgs.coreutils
    pkgs.gitMinimal
  ];
  expectedArtifactRevision = "e41340bec587b6d049b5cc518ec7db925dde84be";
  expectedArtifactNarHash = "sha256-2cM912L2YXVnVX9LquwhAPKyjPP/z/oFQRe7Qq9bHHE=";
  artifactSource = self.lib.inputs.cairn.inputs.artifact;
  kilnNixCommand = brokerSettings.adapters.kiln.env.KILN_NIX;
  expectedConcurrentAdapters = 1;
  bytesPerMebibyte = 1024 * 1024;
  expectedMaxOutputMebibytes = 8;
  expectedMaxOutputBytes = expectedMaxOutputMebibytes * bytesPerMebibyte;
  expectedMemoryMax = "24G";
  expectedCpuQuota = "800%";
  expectedReportDirectory = "/var/lib/radicle-ci/reports";
  expectedReportHostname = "ci.onix.computer";
  expectedReportUrlPrefix = "/reports";
  expectedReportBaseUrl = "https://${expectedReportHostname}${expectedReportUrlPrefix}";
  expectedReportBindAddress = "127.0.0.1";
  expectedReportPort = 8990;
  expectedReportUser = "radicle";
  expectedReportGroup = "radicle";
  expectedReportBackendUrl = "http://${expectedReportBindAddress}:${toString expectedReportPort}";
  expectedReportRouterRule = "Host(`${expectedReportHostname}`) && (Path(`${expectedReportUrlPrefix}`) || PathPrefix(`${expectedReportUrlPrefix}/`))";
  expectedReportTailnetSourceRange = "100.64.0.0/10";
  expectedReportMemoryMax = "256M";
  expectedReportCpuQuota = "100%";
  expectedAdapterCommand = "${
    self.lib.inputs.kiln.packages.${pkgs.stdenv.hostPlatform.system}.default
  }/bin/kiln-adapter-radicle";
  expectedTrigger = {
    adapter = "kiln";
    filters = [
      {
        And = [
          { Repository = seaglassRid; }
          { HasFile = "flake.nix"; }
          "DefaultBranch"
        ];
      }
    ];
  };
  kilnTriggers = builtins.filter (trigger: trigger.adapter == "kiln") brokerSettings.triggers;
  admitsRepository =
    rid:
    builtins.any (
      trigger:
      builtins.any (
        filter: filter ? And && builtins.elem { Repository = rid; } filter.And
      ) trigger.filters
    ) kilnTriggers;
  positivePolicyValid =
    brokerSettings.adapters.kiln.command == expectedAdapterCommand
    && brokerSettings.adapters.kiln.env.KILN_ADAPTER_PROTOCOL == "defelo"
    && brokerSettings.adapters.kiln.env.KILN_MAX_OUTPUT_BYTES == toString expectedMaxOutputBytes
    && brokerSettings.adapters.kiln.env.KILN_REPORT_DIR == expectedReportDirectory
    && brokerSettings.adapters.kiln.env.KILN_REPORT_BASE_URL == expectedReportBaseUrl
    && brokerSettings.adapters.kiln.env.PATH == expectedKilnPath
    && artifactSource.rev == expectedArtifactRevision
    && artifactSource.narHash == expectedArtifactNarHash
    && brokerSettings.max_run_time == expectedMaxRunTime
    && brokerSettings.concurrent_adapters == expectedConcurrentAdapters
    && kilnTriggers == [ expectedTrigger ]
    && admitsRepository seaglassRid
    && brokerServiceConfig.MemoryMax == expectedMemoryMax
    && brokerServiceConfig.CPUQuota == expectedCpuQuota;
  negativeRepositoryRejected = !(admitsRepository privatePilotRid);
  reportServingPolicyValid =
    reportServerConfig.User == expectedReportUser
    && reportServerConfig.Group == expectedReportGroup
    && reportServerConfig.WorkingDirectory == expectedReportDirectory
    && reportServerConfig.MemoryMax == expectedReportMemoryMax
    && reportServerConfig.CPUQuota == expectedReportCpuQuota
    && reportServerConfig.ProtectSystem == "strict"
    && reportServerConfig.ReadOnlyPaths == [ expectedReportDirectory ]
    && reportServerConfig.IPAddressAllow == [ "localhost" ]
    && reportServerConfig.IPAddressDeny == [ "any" ]
    && reportServer.unitConfig.RequiresMountsFor == expectedReportDirectory
    && builtins.elem "radicle-ci-broker.service" reportServer.after
    && builtins.elem "radicle-ci-broker.service" reportServer.requires
    && reportRouter.rule == expectedReportRouterRule
    && reportRouter.service == reportServerName
    && reportRouter.entryPoints == [ "websecure" ]
    &&
      reportRouter.middlewares == [
        reportTailnetMiddlewareName
        reportStripPrefixMiddlewareName
        "security-headers"
      ]
    && reportRouter.tls.certResolver == "letsencrypt"
    && reportBackend.loadBalancer.servers == [ { url = expectedReportBackendUrl; } ]
    && reportStripPrefixMiddleware.stripPrefix.prefixes == [ expectedReportUrlPrefix ]
    && reportTailnetMiddleware.ipAllowList.sourceRange == [ expectedReportTailnetSourceRange ];
  negativeReportExposureRejected =
    expectedReportBindAddress != "0.0.0.0"
    && expectedReportBindAddress != "::"
    && !(builtins.elem expectedReportPort desktopConfig.networking.firewall.allowedTCPPorts);
  replicationPolicyValid =
    replicationServiceConfig.Type == "oneshot"
    && replicationServiceConfig.RemainAfterExit
    && replicationServiceConfig.User == "root"
    && replicationServiceConfig.Group == "root"
    && replicationServiceConfig.ProtectHome == "read-only"
    && replicationServiceConfig.ProtectSystem == "strict"
    && replicationService.unitConfig.RequiresMountsFor == "/var/lib/radicle"
    && builtins.elem "radicle-node.service" replicationService.after
    && builtins.elem "radicle-node.service" replicationService.requires;
in
{
  checks.seaglass-kiln-ci-policy =
    assert lib.assertMsg positivePolicyValid
      "Seaglass Kiln CI settings do not match the reviewed adapter, trigger, or resource policy";
    assert lib.assertMsg negativeRepositoryRejected
      "the Kiln trigger must reject the non-Seaglass private pilot repository";
    assert lib.assertMsg reportServingPolicyValid
      "Seaglass report serving lost its loopback backend, tailnet route, or read-only service boundary";
    assert lib.assertMsg negativeReportExposureRejected
      "the Seaglass report backend must not use a wildcard bind or global firewall port";
    assert lib.assertMsg replicationPolicyValid
      "the private Seaglass replication shell lost its reviewed service boundary";
    pkgs.runCommand "seaglass-kiln-ci-policy-check" { } ''
      test -x ${lib.escapeShellArg expectedAdapterCommand}
      test -x ${lib.escapeShellArg kilnNixCommand}
      grep -F -- ${lib.escapeShellArg "--override-input cairn/artifact"} ${lib.escapeShellArg kilnNixCommand} >/dev/null
      grep -F -- ${lib.escapeShellArg (toString artifactSource)} ${lib.escapeShellArg kilnNixCommand} >/dev/null
      test -x ${lib.escapeShellArg replicationCommand}
      printf '%s\n' ${lib.escapeShellArg reportServerCommand} | grep -F -- ${lib.escapeShellArg "--host ${expectedReportBindAddress}"} >/dev/null
      printf '%s\n' ${lib.escapeShellArg reportServerCommand} | grep -F -- ${lib.escapeShellArg "--port ${toString expectedReportPort}"} >/dev/null
      printf '%s\n' ${lib.escapeShellArg reportServerCommand} | grep -F -- ${lib.escapeShellArg "--root ${expectedReportDirectory}"} >/dev/null
      printf '%s\n' ${lib.escapeShellArg reportServerCommand} | grep -F -- ${lib.escapeShellArg "--directory-listing false"} >/dev/null
      printf '%s\n' ${lib.escapeShellArg reportServerCommand} | grep -F -- ${lib.escapeShellArg "--disable-symlinks true"} >/dev/null
      if printf '%s\n' ${lib.escapeShellArg reportServerCommand} | grep -F -- "--host 0.0.0.0" >/dev/null; then
        echo "the Seaglass report backend must not bind a wildcard address" >&2
        exit 1
      fi
      test -x ${lib.escapeShellArg ddclientPrivateCommand}
      grep -F -- ${lib.escapeShellArg expectedReportHostname} ${lib.escapeShellArg ddclientPrivateCommand} >/dev/null
      grep -F -- ${lib.escapeShellArg seaglassRid} ${lib.escapeShellArg replicationCommand} >/dev/null
      grep -F -- ${lib.escapeShellArg seaglassRevision} ${lib.escapeShellArg replicationCommand} >/dev/null
      grep -F -- ${lib.escapeShellArg seaglassIdentityRevision} ${lib.escapeShellArg replicationCommand} >/dev/null
      grep -F -- ${lib.escapeShellArg personalNodeId} ${lib.escapeShellArg replicationCommand} >/dev/null
      if grep -F -- ${lib.escapeShellArg privatePilotRid} ${lib.escapeShellArg replicationCommand} >/dev/null; then
        echo "private Seaglass replication must reject the unrelated pilot repository" >&2
        exit 1
      fi
      touch "$out"
    '';
}
