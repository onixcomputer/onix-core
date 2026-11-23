# Read-only bridge for shared NixOS files that still use Clan's vars API.
#
# Tag files shared with the Clan build (nix-signing, initrd-ssh,
# remote-builders, berkeley-mono-font) declare `clan.core.vars.generators`
# and read `files.<file>.path`. In the OnixOS build those secrets are OnixOS
# artifacts declared by typed Nickel modules (onixos/services), stored under
# onixos/secrets/{machines/<machine>,shared}/<generator>/<file> and decrypted
# by sops-nix as `sops.secrets."<generator>/<file>"`. This module accepts the
# Clan declarations and resolves each path to that artifact; it generates and
# decrypts nothing itself. Remove it once those tag files are ported.
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
  topConfig = config;
  machineName = config.networking.hostName;

  fileModule =
    generator:
    { name, config, ... }:
    {
      freeformType = types.attrsOf types.anything;
      options = {
        secret = mkOption {
          type = types.bool;
          default = true;
        };
        deploy = mkOption {
          type = types.bool;
          default = true;
        };
        neededFor = mkOption {
          type = types.enum [
            "activation"
            "partitioning"
            "services"
            "users"
          ];
          default = "services";
        };
        path = mkOption {
          type = types.str;
          readOnly = true;
          description = "Runtime path of this file in the OnixOS build.";
          default =
            let
              relDir =
                if generator.share then
                  "shared/${generator.name}"
                else
                  "per-machine/${machineName}/${generator.name}";
              artifact = "${generator.name}/${name}";
            in
            if !config.deploy then
              "/no-such-path"
            else if !config.secret then
              throw "clan-vars-compat: public file ${artifact} has no runtime path in the OnixOS build"
            else if config.neededFor == "activation" then
              # `clan machines update` uploads activation secrets as plaintext.
              # OnixOS has no such upload, so the file already on the host is
              # reused unchanged.
              "/var/lib/sops-nix/activation/${relDir}/${name}"
            else if config.neededFor == "services" then
              topConfig.sops.secrets.${artifact}.path
                or (throw "clan-vars-compat: ${machineName} has no OnixOS artifact ${artifact}")
            else
              throw "clan-vars-compat: neededFor=${config.neededFor} (${artifact}) is not bridged; declare it in its Nickel module";
        };
      };
    };

  generatorModule =
    { name, config, ... }:
    {
      freeformType = types.attrsOf types.anything;
      options = {
        share = mkOption {
          type = types.bool;
          default = false;
        };
        files = mkOption {
          type = types.attrsOf (
            types.submodule (fileModule {
              inherit name;
              inherit (config) share;
            })
          );
          default = { };
        };
      };
    };
in
{
  options.clan.core = {
    vars.generators = mkOption {
      type = types.attrsOf (types.submodule generatorModule);
      default = { };
    };
    # Set by inventory/tags/nixos.nix. clan-carryover.nix sets
    # system.stateVersion explicitly; defaultGroups only affects the Clan CLI.
    settings.state-version.enable = mkOption {
      type = types.bool;
      default = false;
    };
    sops.defaultGroups = mkOption {
      type = types.listOf types.str;
      default = [ ];
    };
  };
}
