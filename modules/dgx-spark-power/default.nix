# DGX Spark GPU power profile (max-clock cap).
#
# Serving decode is memory-bound, so capping the GPU clock does not reduce
# decode output. It does reduce prefill and other compute-bound work. On one
# sample the cap reduced driver-reported GPU power from ~47 W at boost
# (2455 MHz) to ~32 W at 2200 MHz and GPU temperature from ~72 C to ~66 C.
# Wall power is higher than driver-reported power; measure the real delta at
# the PDU.
#
# nvidia-smi clock locks do not survive a reboot. This module applies the cap
# at boot and releases it when the unit stops, so a reboot cannot silently
# return a Spark to boost clocks. Release the cap for prefill-heavy runs with
# `systemctl stop dgx-spark-power` or `nvidia-smi -rgc`.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.dgx-spark-power;
  unitName = "dgx-spark-power";
  driverPackage = config.hardware.nvidia.package or null;
  smiPathCandidates =
    (if cfg.nvidiaSmiPath != null then [ cfg.nvidiaSmiPath ] else [ ])
    ++ (if driverPackage != null then [ "${driverPackage}/bin/nvidia-smi" ] else [ ])
    ++ (
      if driverPackage != null && driverPackage ? bin then
        [ "${driverPackage.bin}/bin/nvidia-smi" ]
      else
        [ ]
    );
  candidateList = lib.concatStringsSep " " smiPathCandidates;
  clockLockArg = "${toString cfg.minClockMHz},${toString cfg.maxClockMHz}";
in
{
  options.services.dgx-spark-power = {
    enable = lib.mkEnableOption "the DGX Spark GPU max-clock cap";

    maxClockMHz = lib.mkOption {
      type = lib.types.int;
      default = 2200;
      description = ''
        GPU clock ceiling in MHz. 2200 MHz is the measured knee: it saves
        roughly 15 W per GPU over boost with minimal compute-cost growth.
        Lower settings save only 4-5 W per step while cost grows.
      '';
    };

    minClockMHz = lib.mkOption {
      type = lib.types.int;
      default = 0;
      description = ''
        GPU clock floor in MHz. Keep 0 so the GPU can still downlock to idle
        clocks when load is low.
      '';
    };

    applyAtBoot = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Apply the cap at boot. Disable to apply it from the runbook only.";
    };

    nvidiaSmiPath = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Explicit nvidia-smi binary. The service auto-detects it when null.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.maxClockMHz > 0;
        message = "services.dgx-spark-power.maxClockMHz must be positive, got ${toString cfg.maxClockMHz}.";
      }
    ];

    systemd.services.${unitName} = {
      description = "Cap DGX Spark GPU max clock to the serving power profile";
      wantedBy = lib.mkIf cfg.applyAtBoot [ "multi-user.target" ];
      after = [ "nvidia-persistenced.service" ];
      wants = [ "nvidia-persistenced.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Release the cap when the unit stops. Stops are operator-initiated
        # (prefill-heavy run) or shutdown, where releasing is harmless.
        ExecStop =
          if driverPackage != null then
            "${driverPackage}/bin/nvidia-smi -rgc"
          else
            "${pkgs.coreutils}/bin/true";
      };
      script = ''
        set -eu

        nvidia_smi=""
        if command -v nvidia-smi >/dev/null 2>&1; then
          nvidia_smi="$(command -v nvidia-smi)"
        fi
        for candidate in ${candidateList}; do
          if [ -z "$nvidia_smi" ] && [ -x "$candidate" ]; then
            nvidia_smi="$candidate"
          fi
        done
        if [ -z "$nvidia_smi" ]; then
          echo "dgx-spark-power: nvidia-smi not found; clock cap not applied" >&2
          exit 1
        fi

        count="$("$nvidia_smi" --query-gpu=count --format=csv,noheader)"
        index=0
        while [ "$index" -lt "$count" ]; do
          "$nvidia_smi" -i "$index" -lgc ${clockLockArg}
          index=$((index + 1))
        done
      '';
    };
  };
}
