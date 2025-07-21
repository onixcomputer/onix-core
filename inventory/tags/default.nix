{ inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;

  tagFiles = lib.filterAttrs (
    name: type: type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix"
  ) (builtins.readDir ./.);

  mkTagInstance =
    filename: _:
    let
      tagName = lib.removeSuffix ".nix" filename;

      # all.nix -> base-settings, others -> tag-tools
      instanceName = if tagName == "all" then "base-settings" else "${tagName}-tools";
    in
    {
      ${instanceName} = {
        module.name = "importer";
        roles.default.tags.${tagName} = { };
        roles.default.extraModules = [ ./${filename} ];
      };
    };

  allInstances = lib.mapAttrsToList mkTagInstance tagFiles;

  mergedInstances = lib.foldl' (acc: inst: acc // inst) { } allInstances;
in
{
  instances = mergedInstances;
}
