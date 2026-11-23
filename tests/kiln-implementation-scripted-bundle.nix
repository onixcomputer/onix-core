# Strict constructor: every executed consumer is a required real immutable input.
{ pkgs, lib, cohort, fixtureHelper, cairnSource, cairnPolicy, hostOwnerContract }:
let
  immutable = value: lib.hasPrefix "/nix/store/" (toString value);
  campaignCohort = import ../modules/kiln-implementer/campaign-cohort.nix { inherit pkgs lib; } {
    inherit (cohort) kiln lattice cairn worker workflow;
    revisions = {
      kiln = cohort.entries.coordinator.revision;
      lattice = cohort.entries.lattice.revision;
      cairn = cohort.entries.cairn.revision;
      worker = cohort.entries.worker.revision;
      nixpkgs = cohort.entries.nix.revision;
    };
  };
  result = pkgs.runCommand "kiln-implementation-scripted-inputs" {
    nativeBuildInputs = [ pkgs.b3sum pkgs.nickel pkgs.python3 pkgs.git pkgs.util-linux ];
    passthru = {
      inherit cohort campaignCohort fixtureHelper cairnSource cairnPolicy;
      configuration = "${result}/configuration";
      attemptBundle = "${result}/attempt";
      ciServiceProfile = "${result}/ci-service-profile.json";
      campaignDriveProfile = "${result}/campaign/drive-profile.json";
      campaignStartCommand = "${result}/campaign/start-command-template.json";
      canonicalCiStatePaths = [ "/var/lib/kiln-implementation/canonical-ci" ];
      # The exact enrollment the bundle's profile.ncl exports.
      repositories = [ "qualification/disposable" ];
      workClasses = [ "bug" ];
      # This is the canonical Engine's sole owned state. Verification invokes
      # the real web-service CLI against this exact profile/state, not a mirror.
      canonicalCiModule = { ... }: {
        systemd.tmpfiles.rules = [
          "d /var/lib/kiln-implementation/canonical-ci 0700 kiln-implementation-verifier kiln-implementation-ledger -"
        ];
      };
    };
  } ''
    set -euo pipefail
    test -x ${lib.escapeShellArg "${fixtureHelper}/bin/kiln-implementation-fixture"}
    test -d ${lib.escapeShellArg "${cairnSource}/fixtures/basic/.cairn"}
    test -f ${lib.escapeShellArg (toString cairnPolicy)}
    ${pkgs.python3}/bin/python3 ${./kiln-implementation-fixtures/build_bundle.py} \
      --cohort ${lib.escapeShellArg (toString cohort)} \
      --fixture-helper ${lib.escapeShellArg "${fixtureHelper}/bin/kiln-implementation-fixture"} \
      --cairn-source ${lib.escapeShellArg (toString cairnSource)} \
      --cairn-policy ${lib.escapeShellArg (toString cairnPolicy)} \
      --python ${pkgs.python3}/bin/python3 \
      --github-fixture ${./kiln-implementation-github-fixture.py} \
      --host-owner-contract ${lib.escapeShellArg (toString hostOwnerContract)} \
      --fixtures ${./kiln-implementation-fixtures} --output "$out" --scratch "$TMPDIR/construction"
    ${pkgs.python3}/bin/python3 ${./kiln-implementation-fixtures/prepare_campaign_bundle.py} \
      --output "$out" --cohort ${lib.escapeShellArg (toString cohort)} \
      --campaign-cohort ${lib.escapeShellArg (toString campaignCohort)} \
      --drive-contract ${lib.escapeShellArg "${campaignCohort.kiln}/share/kiln/implementation-campaign-drive.ncl"} \
      --campaign-constructor ${lib.escapeShellArg (toString ../modules/kiln-implementer/campaign-profile.ncl)} \
      --setpriv ${lib.escapeShellArg "${pkgs.util-linux}/bin/setpriv"}
  '';
in
assert pkgs.stdenv.hostPlatform.system == "x86_64-linux";
assert builtins.all immutable [ cohort campaignCohort fixtureHelper cairnSource cairnPolicy ];
result
