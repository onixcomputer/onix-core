# DGX Spark GPU power-profile checks.
#
# Verifies the power-profile policy fixed in this change:
#   - the dgx-spark tag enables the max-clock cap at boot
#   - the chosen profile is 0,2200 MHz and reaches the generated unit text
#   - the boot unit releases the cap on stop (nvidia-smi -rgc)
#   - a disabled profile removes the unit entirely
#   - the module defaults to off when imported without the tag
#   - a non-positive ceiling trips the module's own assertion
#
# Positive and negative fixtures only. No check opens an SSH connection or
# builds a Spark closure.
{
  self,
  pkgs,
  lib,
  ...
}:
let
  stateVersion = "25.11";
  nixpkgsLib = self.lib.inputs.nixpkgs.lib;
  mkSystem =
    modules:
    nixpkgsLib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = {
        inherit self;
        inputs = self.lib.inputs;
      };
      modules = modules ++ [ { system.stateVersion = stateVersion; } ];
    };

  positiveSystem = mkSystem [ ../inventory/tags/dgx-spark.nix ];
  positiveConfig = positiveSystem.config;
  powerConfig = positiveConfig.services.dgx-spark-power;
  powerUnit = positiveConfig.systemd.services.dgx-spark-power or null;
  powerUnitName = "dgx-spark-power.service";
  powerUnitText = positiveConfig.systemd.units.${powerUnitName}.text;
  expectedClockLock = "-lgc 0,2200";
  clockCeiling = 2200;
  clockFloor = 0;

  disabledSystem = mkSystem [
    ../inventory/tags/dgx-spark.nix
    { services.dgx-spark-power.enable = lib.mkForce false; }
  ];
  disabledConfig = disabledSystem.config;

  standaloneSystem = mkSystem [ ../modules/dgx-spark-power ];
  standaloneConfig = standaloneSystem.config;

  badClockSystem = mkSystem [
    ../modules/dgx-spark-power
    {
      services.dgx-spark-power.enable = true;
      services.dgx-spark-power.maxClockMHz = 0;
    }
  ];
  badClockAssertions = badClockSystem.config.assertions;
  badClockAssertionFound = lib.any (
    assertion: !assertion.assertion && lib.hasInfix "maxClockMHz" assertion.message
  ) badClockAssertions;

  powerAssertions = [
    {
      name = "positive: dgx-spark tag enables the power profile at boot";
      condition =
        powerConfig.enable && powerUnit != null && lib.elem "multi-user.target" powerUnit.wantedBy;
    }
    {
      name = "positive: power profile pins clock floor 0 and ceiling 2200 MHz";
      condition = powerConfig.minClockMHz == clockFloor && powerConfig.maxClockMHz == clockCeiling;
    }
    {
      name = "positive: clock cap and driver wiring reach the rendered configuration";
      condition =
        lib.hasInfix expectedClockLock powerUnit.script
        && lib.hasInfix "--query-gpu=count" powerUnit.script
        && (powerUnit.serviceConfig.ExecStart or "") != ""
        && lib.hasInfix "ExecStart" powerUnitText;
    }
    {
      name = "positive: unit releases the cap on stop";
      condition =
        lib.hasInfix "-rgc" powerUnit.serviceConfig.ExecStop
        && lib.hasInfix "ExecStop" powerUnitText
        && powerUnit.serviceConfig.Type == "oneshot";
    }
    {
      name = "negative: disabled profile removes the whole unit";
      condition =
        !disabledConfig.services.dgx-spark-power.enable
        && !builtins.hasAttr "dgx-spark-power" disabledConfig.systemd.services;
    }
    {
      name = "negative: module defaults to off without the dgx-spark tag";
      condition =
        !standaloneConfig.services.dgx-spark-power.enable
        && !builtins.hasAttr "dgx-spark-power" standaloneConfig.systemd.services;
    }
    {
      name = "negative: non-positive ceiling trips the module assertion";
      condition = badClockAssertionFound;
    }
  ];
  failedPowerAssertions = lib.filter (assertion: !assertion.condition) powerAssertions;
in
{
  checks.dgx-spark-power = pkgs.runCommand "dgx-spark-power" { } ''
    ${lib.optionalString (failedPowerAssertions != [ ]) ''
      echo "DGX Spark power-profile checks failed:" >&2
      printf '%s\n' ${lib.escapeShellArgs (map (assertion: assertion.name) failedPowerAssertions)} >&2
      exit 1
    ''}
    touch $out
  '';
}
