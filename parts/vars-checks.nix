# Validate clan secrets and vars consistency at check time.
#
# - secrets: runs `clan secrets key update` to verify all secret owners
#   and access control are consistent with the sops config.
# - vars: runs `clan vars check` + `clan vars fix` for every machine
#   to catch stale or missing vars before deploy.
#
# Adapted from clan-infra's checks/secrets.nix and checks/vars.nix.
{
  self,
  inputs',
  pkgs,
  lib,
  system,
  ...
}:
let
  inherit (self) inputs;

  clanLegacy = inputs.clan-core.legacyPackages.${system};

  # Closure of all flake inputs so nix eval works inside the sandbox
  allInputPaths = map (x: x.key) (
    lib.genericClosure {
      startSet = lib.mapAttrsToList (_: input: {
        key = input.outPath or input;
        inherit input;
      }) inputs;
      operator =
        { input, ... }:
        lib.mapAttrsToList (_: i: {
          key = i.outPath or i;
          input = i;
        }) (input.inputs or { });
    }
  );

  flakeInputsClosure = pkgs.closureInfo { rootPaths = allInputPaths; };

  machineNames = lib.attrNames (import ../inventory/core/machines.nix { }).machines;
in
{
  checks = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    secrets =
      pkgs.runCommand "check-secrets"
        {
          nativeBuildInputs = [
            inputs'.clan-core.clan-cli
            pkgs.nixVersions.latest
            pkgs.sops
          ];
          closureInfo = flakeInputsClosure;
        }
        ''
          ${clanLegacy.setupNixInNix}
          mkdir -p self
          cp -r --no-target-directory ${self} self
          CLAN_LOAD_AGE_PLUGINS=false clan secrets key update --flake ./self
          touch $out
        '';

    vars =
      pkgs.runCommand "check-vars"
        {
          nativeBuildInputs = [
            inputs'.clan-core.clan-cli
            pkgs.nixVersions.latest
            pkgs.sops
          ];
          env.closureInfo = flakeInputsClosure;
        }
        ''
          ${clanLegacy.setupNixInNix}
          mkdir -p self
          cp -r --no-target-directory ${self} self
          ${lib.concatMapStringsSep "\n" (machine: ''
            clan vars check ${machine} --flake ./self --debug
            clan vars fix ${machine} --flake ./self --debug
          '') machineNames}
          touch $out
        '';
  };
}
