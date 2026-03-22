_: {
  _class = "clan.service";

  manifest = {
    name = "home-manager-profiles";
    description = "Profile-based home-manager configuration for user environments";
    readme = "Profile-based home-manager configuration for declarative user environments";
    categories = [ "System" ];
  };

  roles.default = {
    description = "Configure home-manager profiles for a user on target machines";

    interface =
      { lib, ... }:
      {
        options = {
          username = lib.mkOption {
            type = lib.types.str;
            description = "Username to configure home-manager for";
          };

          profiles = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Home-manager profile directories to load from the user's profile path";
          };

          profilesBasePath = lib.mkOption {
            type = lib.types.path;
            description = "Base path containing per-user profile directories";
          };
        };
      };

    perInstance =
      { settings, ... }:
      {
        nixosModule =
          {
            config,
            lib,
            inputs,
            ...
          }:
          let
            userProfilePath = settings.profilesBasePath + "/${settings.username}";

            # Collect all .nix files and directories (with default.nix) from each profile
            profileImports = builtins.concatMap (
              profileName:
              let
                profileDir = userProfilePath + "/${profileName}";
                entries = builtins.readDir profileDir;
                # Regular .nix files
                nixFiles = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name) entries;
                # Directories containing a default.nix
                nixDirs = lib.filterAttrs (
                  name: type: type == "directory" && builtins.pathExists (profileDir + "/${name}/default.nix")
                ) entries;
              in
              (lib.mapAttrsToList (name: _: profileDir + "/${name}") nixFiles)
              ++ (lib.mapAttrsToList (name: _: profileDir + "/${name}") nixDirs)
            ) settings.profiles;
          in
          {
            imports = [
              inputs.home-manager.nixosModules.home-manager
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  backupFileExtension = "hm-bak";
                  extraSpecialArgs = {
                    inherit inputs;
                  };

                  users.${settings.username} = {
                    imports = profileImports;
                    home.stateVersion = lib.mkDefault config.system.stateVersion;
                  };
                };
              }
            ];
          };
      };
  };
}
