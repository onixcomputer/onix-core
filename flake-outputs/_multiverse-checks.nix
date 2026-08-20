# nixpkgs-multiverse module integration checks.
#
# Positive: the multiverse NixOS module imports into our evaluation, a pin
# round-trips through the option system, the pin plan resolves offline, the
# wrapper installs exactly the resolved pin set, and the repository's real
# multiverse.lock parses through the module. The index files ship inside the
# multiverse checkout, so forcing `plan` and shallow `pinned`/`locked`
# structure reads local JSON only — no nixpkgs revision is fetched at check
# time (attribute lookups and length never force a derivation).
#
# Negative: an attribute claimed by both `multiverse.pins` and
# `multiverse.cooldown.packages` produces a failing assertion (instead of a
# buildEnv file collision at build time), a non-string pin value fails the
# option type check, and a lock file with an unknown format version throws.
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

  # The repository's real lock file must parse through the module: readLock
  # checks the format version before anything else, so a successful (shallow)
  # force is also a version check. attrNames never forces a derivation, so a
  # populated lock still costs no fetch here.
  lockEval = evalWith {
    multiverse = {
      enable = true;
      lock = ../multiverse.lock;
    };
  };
  lockParsed = builtins.attrNames lockEval.config.multiverse.locked;
  lockInstalled = builtins.length lockEval.config.multiverse.packages;
  lockOk = lockParsed == [ ] && lockInstalled == 0;

  # A lock declaring an unknown format version must throw rather than being
  # read as if nothing were wrong.
  badLock = builtins.toFile "multiverse.lock" (
    builtins.toJSON {
      version = 999;
      pins = { };
    }
  );
  badLockEval = builtins.tryEval (
    builtins.seq
      (evalWith {
        multiverse = {
          enable = true;
          lock = badLock;
        };
      }).config.multiverse.locked
      null
  );
  badLockOk = !badLockEval.success;
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
      ${lib.optionalString (!lockOk) ''
        echo "multiverse repository lock did not parse cleanly:"
        echo "  attrs: ${builtins.toString lockParsed}"
        echo "  packages installed from it: ${toString lockInstalled}"
        exit 1
      ''}
      ${lib.optionalString (!badLockOk) ''
        echo "multiverse accepted a lock file with an unknown format version"
        exit 1
      ''}
      touch $out
    '';
  };
}
