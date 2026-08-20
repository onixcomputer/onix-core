# nixpkgs-multiverse module integration checks.
#
# Positive: the multiverse NixOS module imports into our evaluation, a pin
# round-trips through the option system, the pin plan resolves offline, and
# the wrapper installs exactly the resolved pin set. The index files ship
# inside the multiverse checkout, so forcing `plan` and `pinned` structure
# reads local JSON only — no nixpkgs revision is fetched at check time.
#
# Negative: an attribute claimed by both `multiverse.pins` and
# `multiverse.cooldown.packages` produces a failing assertion (instead of a
# buildEnv file collision at build time), and a non-string pin value fails
# the option type check.
{
  inputs',
  pkgs,
  lib,
  ...
}:
let
  # The wrapper installs pins via environment.systemPackages and reports
  # problems via assertions/warnings; declare stubs so evalModules works
  # without importing the full NixOS base module.
  stubModule = {
    options = {
      environment.systemPackages = lib.mkOption {
        type = lib.types.listOf lib.types.raw;
        default = [ ];
      };
      assertions = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
      };
      warnings = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
    };
  };

  evalWith =
    extra:
    lib.evalModules {
      modules = [
        stubModule
        inputs'.multiverse.nixosModules.default
        extra
      ];
      specialArgs = { inherit pkgs; };
    };

  positive = evalWith {
    multiverse = {
      enable = true;
      pins.ripgrep = "13.0.0";
    };
  };

  positiveResults = {
    planRevisions = positive.config.multiverse.plan.revisions;
    pinResolved = positive.config.multiverse.pinned ? ripgrep;
    packageCount = builtins.length positive.config.multiverse.packages;
    installedCount = builtins.length positive.config.environment.systemPackages;
  };
  positiveOk =
    positiveResults.planRevisions == 1
    && positiveResults.pinResolved
    && positiveResults.packageCount == 1
    && positiveResults.installedCount == 1;

  contested = evalWith {
    multiverse = {
      enable = true;
      pins.ripgrep = "13.0.0";
      cooldown.packages = [ "ripgrep" ];
    };
  };
  failingAssertions = builtins.filter (a: !a.assertion) contested.config.assertions;
  negativeOk =
    (builtins.length failingAssertions == 1)
    && (lib.hasInfix "claimed by more than" (builtins.head failingAssertions).message);

  # tryEval forces only to WHNF, so force the pin value itself to trigger
  # the attrsOf str type check on the merged option.
  typeError = builtins.tryEval (
    builtins.seq
      (evalWith {
        multiverse = {
          enable = true;
          pins.ripgrep = 13;
        };
      }).config.multiverse.pins.ripgrep
      null
  );
  typeErrorOk = !typeError.success;
in
{
  checks = {
    multiverse-module = pkgs.runCommand "multiverse-module" { } ''
      ${lib.optionalString (!positiveOk) ''
        echo "multiverse positive wiring failed:"
        printf '%s\n' ${lib.escapeShellArg (builtins.toJSON positiveResults)}
        exit 1
      ''}
      ${lib.optionalString (!negativeOk) ''
        echo "multiverse duplicate-claim assertion did not fire:"
        printf '%s\n' ${lib.escapeShellArg (builtins.toJSON failingAssertions)}
        exit 1
      ''}
      ${lib.optionalString (!typeErrorOk) ''
        echo "multiverse pin type check accepted a non-string value"
        exit 1
      ''}
      touch $out
    '';
  };
}
