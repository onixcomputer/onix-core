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
  seaglassRid = "rad:z3xXXCQXCTquvAawh41YYs8yC8xmk";
  seaglassRevision = "bea681be760e76a7e18a663df6ed38c2a9d0e1c6";
  seaglassIdentityRevision = "34622578746c320714509e309233fc7df051d202";
  personalNodeId = "z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx";
  privatePilotRid = "rad:z3t9ykR1HfG9UkyKoQQg5ikkzrTxg";
  expectedMaxRunTime = "2h";
  expectedKilnPath = lib.makeBinPath [
    pkgs.coreutils
    pkgs.gitMinimal
  ];
  expectedConcurrentAdapters = 1;
  bytesPerMebibyte = 1024 * 1024;
  expectedMaxOutputMebibytes = 8;
  expectedMaxOutputBytes = expectedMaxOutputMebibytes * bytesPerMebibyte;
  expectedMemoryMax = "24G";
  expectedCpuQuota = "800%";
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
    && brokerSettings.adapters.kiln.env.PATH == expectedKilnPath
    && brokerSettings.max_run_time == expectedMaxRunTime
    && brokerSettings.concurrent_adapters == expectedConcurrentAdapters
    && kilnTriggers == [ expectedTrigger ]
    && admitsRepository seaglassRid
    && brokerServiceConfig.MemoryMax == expectedMemoryMax
    && brokerServiceConfig.CPUQuota == expectedCpuQuota;
  negativeRepositoryRejected = !(admitsRepository privatePilotRid);
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
    assert lib.assertMsg replicationPolicyValid
      "the private Seaglass replication shell lost its reviewed service boundary";
    pkgs.runCommand "seaglass-kiln-ci-policy-check" { } ''
      test -x ${lib.escapeShellArg expectedAdapterCommand}
      test -x ${lib.escapeShellArg replicationCommand}
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
