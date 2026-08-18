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
  seaglassRid = "rad:z3xXXCQXCTquvAawh41YYs8yC8xmk";
  privatePilotRid = "rad:z3t9ykR1HfG9UkyKoQQg5ikkzrTxg";
  expectedMaxRunTime = "2h";
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
    && brokerSettings.max_run_time == expectedMaxRunTime
    && brokerSettings.concurrent_adapters == expectedConcurrentAdapters
    && kilnTriggers == [ expectedTrigger ]
    && admitsRepository seaglassRid
    && brokerServiceConfig.MemoryMax == expectedMemoryMax
    && brokerServiceConfig.CPUQuota == expectedCpuQuota;
  negativeRepositoryRejected = !(admitsRepository privatePilotRid);
in
{
  checks.seaglass-kiln-ci-policy =
    assert lib.assertMsg positivePolicyValid
      "Seaglass Kiln CI settings do not match the reviewed adapter, trigger, or resource policy";
    assert lib.assertMsg negativeRepositoryRejected
      "the Kiln trigger must reject the non-Seaglass private pilot repository";
    pkgs.runCommand "seaglass-kiln-ci-policy-check" { } ''
      test -x ${lib.escapeShellArg expectedAdapterCommand}
      touch "$out"
    '';
}
