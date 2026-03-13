# Per-machine nix signing key generation + cross-trust.
#
# Each machine generates its own ed25519 signing key via clan vars.
# Public keys from all machines in the repo are auto-discovered and
# added to trusted-public-keys so every machine trusts every other
# machine's builds without manual key distribution.
#
# Adapted from clan-infra's modules/signing.nix.
{
  config,
  self,
  lib,
  ...
}:
let
  flake = import "${self}/flake.nix";

  varsDir = "${self}/vars/per-machine";
  machines = lib.attrNames (builtins.readDir varsDir);

  # Read public signing keys from all machines that have generated one
  allMachineSigningKeys = lib.flatten (
    map (
      machine:
      let
        keyPath = "${varsDir}/${machine}/nix-signing-key/key.pub/value";
      in
      lib.optional (builtins.pathExists keyPath) (lib.fileContents keyPath)
    ) machines
  );
in
{
  clan.core.vars.generators.nix-signing-key = {
    files."key" = { };
    files."key.pub".secret = false;
    runtimeInputs = [ config.nix.package ];
    script = ''
      nix --extra-experimental-features "nix-command flakes" \
        key generate-secret --key-name ${config.networking.hostName}-1 > $out/key
      nix --extra-experimental-features "nix-command flakes" \
        key convert-secret-to-public < $out/key > $out/key.pub
    '';
  };

  nix.settings = {
    # Sign all builds with this machine's key
    secret-key-files = [
      config.clan.core.vars.generators.nix-signing-key.files."key".path
    ];

    # Trust signing keys from all machines in the repo
    trusted-public-keys = allMachineSigningKeys ++ (flake.nixConfig.extra-trusted-public-keys or [ ]);

    # Trust substituters from flake config if present
    substituters = flake.nixConfig.extra-substituters or [ ];

    # Harmonia binary cache on aspen2
    extra-substituters = [ "http://aspen2:5000" ];
  };
}
