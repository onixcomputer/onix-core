# Opt-in Kiln implementation composition (modules/kiln-implementer).
# The qualification tool is an ordinary package. The pinned cohort, scripted
# VM campaign and live-pilot VM live under legacyPackages so that CI's
# package-*/checks sweep never builds or runs them implicitly.
{
  self,
  pkgs,
  lib,
  system,
  ...
}:
let
  qualification = import ../modules/kiln-implementer/qualification-package.nix { inherit pkgs; };
  pinned = import ../modules/kiln-implementer/pinned-cohort.nix {
    inherit pkgs lib;
    inherit (self) inputs;
  };
  scripted = import ./_kiln-implementation-scripted-vm-checks.nix {
    inherit pkgs lib;
    cohort = pinned.fixtureCohort;
    inherit (pinned) fixtureHelper cairnSource cairnPolicy;
    hostOwnerContract = "${self.inputs.kiln-implementation}/config/fair-admission-host-owner.ncl";
  };
  pilot = import ../modules/kiln-implementer/pilot {
    inherit
      pkgs
      lib
      self
      pinned
      ;
  };
  # Host-side operator helpers for the pilot guests (ssh, stage, collect).
  pilotTools = import ../modules/kiln-implementer/pilot/tools.nix { inherit pkgs; };
in
{
  packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    kiln-implementation-qualify = qualification;
  };
  apps = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux (
    {
      kiln-implementation-qualify = {
        type = "app";
        program = "${qualification}/bin/kiln-implementation-qualify";
      };
    }
    // lib.mapAttrs (name: tool: {
      type = "app";
      program = "${tool}/bin/${name}";
    }) pilotTools
  );
  legacyPackages = lib.optionalAttrs (system == "x86_64-linux") {
    kiln-implementation = {
      inherit (pinned)
        cohort
        campaignCohort
        fixtureCohort
        fixtureHelper
        ;
      scripted-inputs = scripted.packages.kiln-implementation-scripted-inputs;
      scripted-vm = scripted.checks.kiln-implementation-scripted-vm;
      receipt = import ../modules/kiln-implementer/receipt-check.nix {
        inherit pkgs lib pinned;
        inherit (self) inputs;
      };
      inherit (pilot)
        pilot-inputs
        pilot-parse
        pilot-resolver
        pilot-vm
        pilot-boot
        pilot-flow
        ;
      pilot-tools = pilotTools;
    };
  };
}
