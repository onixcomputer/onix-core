# Consume the published package and module contracts without copying vault code.
{
  self,
  pkgs,
  lib,
  system,
  ...
}:
let
  upstream = self.inputs.factorseal;
  supported = builtins.hasAttr system upstream.packages;
  evaluate =
    settings:
    (self.inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        self.nixosModules.factorseal
        {
          system.stateVersion = "26.05";
          services.factorseal = settings;
        }
      ];
    }).config;
  disabled = evaluate { };
  enabledSettings = {
    enable = true;
    acceptUnauditedPrototype = true;
    users = [ "factorseal-evaluation" ];
  };
  # A fixture has no boot filesystem. Inspect only Factorseal failures.
  # Successful NixOS assertions can have messages that are invalid to evaluate.
  factorsealFailures =
    config:
    builtins.filter (
      entry: !entry.assertion && lib.hasInfix "factorseal" (lib.toLower entry.message)
    ) config.assertions;
  accepted = config: factorsealFailures config == [ ];
  enabled = evaluate enabledSettings;
  refused = evaluate { enable = true; };
  invalidLease = evaluate (
    enabledSettings // { idleSeconds = enabled.services.factorseal.maximumSeconds + 1; }
  );
  keyringConflict =
    (self.inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        self.nixosModules.factorseal
        {
          system.stateVersion = "26.05";
          services.factorseal = enabledSettings;
          services.gnome.gnome-keyring.enable = true;
        }
      ];
    }).config;
in
{
  packages = lib.optionalAttrs supported {
    inherit (upstream.packages.${system}) factorseal factorseal-desktop;
  };

  checks = lib.optionalAttrs supported {
    factorseal-policy =
      assert !disabled.services.factorseal.enable;
      assert !(builtins.hasAttr "factorseal" disabled.systemd.user.services);
      assert !disabled.services.factorseal.acceptUnauditedPrototype;
      assert accepted enabled;
      assert enabled.security.tpm2.enable;
      assert builtins.elem "factorseal-evaluation"
        enabled.users.groups.${enabled.security.tpm2.tssGroup}.members;
      assert builtins.hasAttr "factorseal" enabled.systemd.user.services;
      assert !(accepted refused);
      assert !(accepted invalidLease);
      assert !(accepted keyringConflict);
      pkgs.runCommand "factorseal-policy" { } ''
        touch "$out"
      '';
  };
}
