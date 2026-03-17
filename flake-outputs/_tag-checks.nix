# Verify that the tag registry in contracts.ncl stays in sync with
# the actual .nix files in inventory/tags/.
#
# Catches two kinds of drift:
#   - Tag registered in contracts.ncl but no .nix file exists
#   - Tag .nix file exists but not registered in contracts.ncl
{
  self,
  pkgs,
  lib,
  ...
}:
let
  plugins = self.packages.x86_64-linux.wasm-plugins;
  wasm = import ../lib/wasm.nix { inherit plugins; };

  tagLists = wasm.evalNickelFile ../inventory/core/tag-lists.ncl;

  # Tags from contracts.ncl that should each have a .nix file
  registeredTags = lib.sort lib.lessThan tagLists.tagFileTags;

  # Auto-computed tags that have .nix files but aren't machine-assignable
  autoTags = tagLists.autoTagsWithFiles;

  # Tags derived from .nix files on disk (minus default.nix)
  tagDir = ../inventory/tags;
  dirEntries = builtins.readDir tagDir;
  fileTags = lib.sort lib.lessThan (
    lib.filter (t: t != "default") (
      map (name: lib.removeSuffix ".nix" name) (
        lib.filter (name: lib.hasSuffix ".nix" name) (lib.attrNames dirEntries)
      )
    )
  );

  # File tags minus the auto-computed ones = tags that must be registered
  fileTagsMinusAuto = lib.filter (t: !lib.elem t autoTags) fileTags;

  # All tags that should have files = registered + auto

  inRegistryNoFile = lib.subtractLists fileTags registeredTags;
  onDiskNoRegistry = lib.subtractLists registeredTags fileTagsMinusAuto;
in
{
  checks = {
    tag-registry-sync = pkgs.runCommand "tag-registry-sync" { } ''
      ${lib.optionalString (inRegistryNoFile != [ ]) ''
        echo "Tags in contracts.ncl tagFileTags but missing .nix file:"
        echo "  ${lib.concatStringsSep " " inRegistryNoFile}"
        echo ""
      ''}
      ${lib.optionalString (onDiskNoRegistry != [ ]) ''
        echo "Tag .nix files not registered in contracts.ncl tagFileTags:"
        echo "  ${lib.concatStringsSep " " onDiskNoRegistry}"
        echo ""
      ''}
      ${lib.optionalString (inRegistryNoFile != [ ] || onDiskNoRegistry != [ ]) ''
        echo "Fix: update tag_file_tags in inventory/core/contracts.ncl"
        exit 1
      ''}
      touch $out
    '';
  };
}
