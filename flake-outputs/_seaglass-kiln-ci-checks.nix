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
  runtimeName = "kiln-aspen-ci";
  aspenAdapterPackage =
    lib.findFirst (package: (package.name or "") == "${runtimeName}-adapter")
      (throw "Kiln Aspen production adapter package is missing")
      desktopConfig.environment.systemPackages;
  expectedAdapterCommand = "${aspenAdapterPackage}/bin/${runtimeName}-adapter";
  expectedConcurrentAdapters = 1;
  expectedMemoryMax = "24G";
  expectedCpuQuota = "800%";
  expectedReportDirectory = "/var/lib/radicle-ci/reports";
  expectedReportHostname = "ci.onix.computer";
  expectedReportUrlPrefix = "/reports";
  expectedReportBindAddress = "127.0.0.1";
  expectedReportPort = 8990;
  expectedReportUser = "radicle";
  expectedReportGroup = "radicle";
  expectedReportBackendUrl = "http://${expectedReportBindAddress}:${toString expectedReportPort}";
  expectedReportRouterRule = "Host(`${expectedReportHostname}`) && (Path(`${expectedReportUrlPrefix}`) || PathPrefix(`${expectedReportUrlPrefix}/`))";
  expectedReportTailnetSourceRange = "100.64.0.0/10";
  expectedReportMemoryMax = "256M";
  expectedReportCpuQuota = "100%";
  expectedLegacyKilnRevision = "8821e9adf15ad28838025bfbdd2e09c8d76fe5db";
  expectedHostedKilnRevision = "8c9338e5c10a0e16ee3042d11583ccccf6efe7e9";
  legacyKilnInput = self.lib.inputs.kiln-ci-legacy;
  hostedKilnInput = self.lib.inputs.kiln;
  legacyAdapterCommand = "${
    legacyKilnInput.packages.${pkgs.stdenv.hostPlatform.system}.default
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
  continuityPinsValid =
    legacyKilnInput.rev == expectedLegacyKilnRevision
    && hostedKilnInput.rev == expectedHostedKilnRevision
    && legacyKilnInput.rev != hostedKilnInput.rev;
  positivePolicyValid =
    brokerSettings.adapters.kiln.command == expectedAdapterCommand
    && brokerSettings.adapters.kiln.env == { }
    && brokerSettings.max_run_time == expectedMaxRunTime
    && brokerSettings.concurrent_adapters == expectedConcurrentAdapters
    && kilnTriggers == [ expectedTrigger ]
    && admitsRepository seaglassRid
    && brokerServiceConfig.MemoryMax == expectedMemoryMax
    && brokerServiceConfig.CPUQuota == expectedCpuQuota;
  negativeRepositoryRejected = !(admitsRepository privatePilotRid);
  # r[verify onix.radicle_ci.seaglass_acquire.rejected]
  # A broker run requires storage presence AND trigger admission. A
  # repository outside the admitted private set must fail admission, or
  # the broker could start a run without any seeded object to execute.
  unseededCandidates = [ privatePilotRid ];
  unseededRunsRejected = builtins.foldl' (
    acc: rid: acc && !(admitsRepository rid)
  ) true unseededCandidates;
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
    assert lib.assertMsg continuityPinsValid
      "the staged Seaglass executor and hosted Kiln inputs must remain separate immutable revisions";
    assert lib.assertMsg positivePolicyValid
      "Seaglass Kiln CI settings do not match the reviewed adapter, trigger, or resource policy";
    assert lib.assertMsg negativeRepositoryRejected
      "the Kiln trigger must reject the non-Seaglass private pilot repository";
    assert lib.assertMsg unseededRunsRejected
      "an unseeded repository must not be admitted by the broker trigger, so it produces no broker run";
    assert lib.assertMsg reportServingPolicyValid
      "Seaglass report serving lost its loopback backend, tailnet route, or read-only service boundary";
    assert lib.assertMsg negativeReportExposureRejected
      "the Seaglass report backend must not use a wildcard bind or global firewall port";
    assert lib.assertMsg replicationPolicyValid
      "the private Seaglass replication shell lost its reviewed service boundary";
    pkgs.runCommand "seaglass-kiln-ci-policy-check" { } ''
      test -x ${lib.escapeShellArg expectedAdapterCommand}
      test -x ${lib.escapeShellArg legacyAdapterCommand}
      adapter_diagnostic="$TMPDIR/aspen-adapter.err"
      if printf '%s' 'not-json' \
        | ${lib.escapeShellArg expectedAdapterCommand} \
          >"$TMPDIR/aspen-adapter.out" 2>"$adapter_diagnostic"; then
        echo "Aspen adapter accepted malformed broker input" >&2
        exit 1
      fi
      grep -F -- 'radicle_json' "$adapter_diagnostic" >/dev/null
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
      grep -F -- "Cloudflare zone lookup failed" ${lib.escapeShellArg ddclientPrivateCommand} >/dev/null
      grep -F -- "Cloudflare DNS record creation failed" ${lib.escapeShellArg ddclientPrivateCommand} >/dev/null
      grep -F -- ${lib.escapeShellArg seaglassRid} ${lib.escapeShellArg replicationCommand} >/dev/null
      grep -F -- ${lib.escapeShellArg seaglassRevision} ${lib.escapeShellArg replicationCommand} >/dev/null
      grep -F -- ${lib.escapeShellArg seaglassIdentityRevision} ${lib.escapeShellArg replicationCommand} >/dev/null
      grep -F -- ${lib.escapeShellArg personalNodeId} ${lib.escapeShellArg replicationCommand} >/dev/null
      # Negative fixture: an unseeded repository produces no broker run.
      # The broker needs storage presence AND trigger admission. The
      # replication writer is the only path into the broker-watched
      # storage, so it must seed exactly one repository and never copy a
      # candidate outside the admitted set.
      seed_invocations="$(grep -c 'rad seed' ${lib.escapeShellArg replicationCommand} || true)"
      if test "$seed_invocations" -ne 1; then
        echo "managed storage writer must seed exactly one repository" >&2
        exit 1
      fi
      for candidate in ${lib.escapeShellArg privatePilotRid}; do
        if grep -Fq -- "$candidate" ${lib.escapeShellArg replicationCommand}; then
          echo "an unseeded repository was copied into managed broker storage: $candidate" >&2
          exit 1
        fi
      done
      touch "$out"
    '';
}
