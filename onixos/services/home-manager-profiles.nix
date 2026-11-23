# home-manager-profiles.ncl emits one onix.homeManagerProfiles.<instance>
# record per instance. Nickel cannot import modules or read directories, so
# this sidecar imports Home Manager's NixOS module and an adapter that turns
# each record into the home-manager definitions onix-core's Clan module
# (modules/home-manager-profiles/default.nix) writes for that instance.
{ inputs, ... }:
let
  # onixos/services/../.. is the flake root; profilesBasePath is relative
  # to it, like inventory/core/default.nix's ../home-profiles.
  flakeRoot = ../..;

  adapter =
    { config, lib, ... }:
    let
      inherit (lib) mkOption types;
      instances = config.onix.homeManagerProfiles;

      # Every .nix file and every directory with a default.nix in each
      # profile, exactly as the Clan module collects them.
      profileImports =
        instance:
        let
          userProfilePath = flakeRoot + "/${instance.profilesBasePath}/${instance.username}";
        in
        builtins.concatMap (
          profileName:
          let
            profileDir = userProfilePath + "/${profileName}";
            entries = builtins.readDir profileDir;
            nixFiles = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name) entries;
            nixDirs = lib.filterAttrs (
              name: type: type == "directory" && builtins.pathExists (profileDir + "/${name}/default.nix")
            ) entries;
          in
          (lib.mapAttrsToList (name: _: profileDir + "/${name}") nixFiles)
          ++ (lib.mapAttrsToList (name: _: profileDir + "/${name}") nixDirs)
        ) instance.profiles;

      instanceConfig = instance: {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "hm-bak";
        extraSpecialArgs = {
          inherit inputs;
        };
        # Package pinning through nixpkgs-multiverse (AGENTS.md "Package pinning").
        sharedModules = [
          inputs.multiverse.homeManagerModules.default
          {
            multiverse.lock = flakeRoot + "/multiverse.lock";
          }
        ];
        users.${instance.username} = {
          imports = profileImports instance;
          home.stateVersion =
            if instance.homeStateVersion == null then
              lib.mkDefault config.system.stateVersion
            else
              instance.homeStateVersion;
        };
      };
    in
    {
      options.onix.homeManagerProfiles = mkOption {
        type = types.attrsOf (
          types.submodule {
            options = {
              username = mkOption {
                type = types.str;
                description = "User the profiles apply to.";
              };
              profiles = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "Profile directories to import.";
              };
              profilesBasePath = mkOption {
                type = types.str;
                description = "Directory of per-user profiles, relative to the flake root.";
              };
              homeStateVersion = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "home.stateVersion; null follows system.stateVersion.";
              };
            };
          }
        );
        default = { };
        description = "Home Manager profile assignments emitted by onixos/services/home-manager-profiles.ncl, keyed by instance.";
      };

      config = lib.mkIf (instances != { }) {
        # Clan defines each instance in its own module, in instance-name
        # order, and the module system merges definitions from separate
        # modules last module first. Definitions inside one mkMerge keep
        # their order, so reverse the instances to merge them as Clan does.
        home-manager = lib.mkMerge (map instanceConfig (lib.reverseList (lib.attrValues instances)));
      };
    };
in
{
  nixosModules = [
    inputs.home-manager.nixosModules.home-manager
    adapter
  ];
}
