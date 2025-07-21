{ inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;

  userDirs = lib.filterAttrs (_name: type: type == "directory") (builtins.readDir ./.);

  mkUserInstances =
    username: _:
    let
      userDir = ./${username};

      stateVersion =
        if builtins.pathExists (userDir + "/stateVersion.nix") then
          import (userDir + "/stateVersion.nix")
        else
          "24.05";

      tagDirs = lib.filterAttrs (_name: type: type == "directory") (builtins.readDir userDir);

      mkTagInstance =
        tagName: _:
        let
          tagDir = userDir + "/${tagName}";

          nixFiles = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name) (
            builtins.readDir tagDir
          );

          configs = lib.mapAttrsToList (name: _: import (tagDir + "/${name}")) nixFiles;

          mergedConfig = lib.mkMerge configs;

          # base folder -> just username, others -> username-tag
          instanceName = if tagName == "base" then username else "${username}-${tagName}";

          # base -> home-manager tag only, others -> both tags
          requiredTags =
            if tagName == "base" then
              { "home-manager" = { }; }
            else
              {
                "home-manager" = { };
                ${tagName} = { };
              };
        in
        {
          ${instanceName} = {
            module.name = "home-manager";
            roles.default.tags = requiredTags;
            roles.default.settings = {
              inherit username stateVersion;
              homeManagerConfig = mergedConfig;
            };
          };
        };

      tagInstances = lib.mapAttrsToList mkTagInstance tagDirs;
    in
    lib.foldl' (acc: inst: acc // inst) { } tagInstances;

  allUserInstances = lib.mapAttrsToList mkUserInstances userDirs;

  mergedInstances = lib.foldl' (acc: inst: acc // inst) { } allUserInstances;
in
{
  instances = mergedInstances;
}
