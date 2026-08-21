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

  dgxSparkRequiredSystem = "aarch64-linux";
  dgxSparkUnsupportedSystem = "x86_64-linux";
  mkDgxSparkSystem =
    system:
    self.lib.inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        inherit self;
        inputs = self.lib.inputs;
      };
      modules = [
        ../inventory/tags/dgx-spark.nix
        {
          system.stateVersion = dgxSparkFixtureStateVersion;
          users.users.${dgxSparkUserName}.openssh.authorizedKeys.keys = [ dgxSparkExcludedKey ];
          users.users.${dgxSparkRootUserName}.openssh.authorizedKeys.keys = [ dgxSparkExcludedKey ];
        }
      ];
    };
  dgxSparkFixtureStateVersion = "25.11";
  dgxSparkUserName = "brittonr";
  dgxSparkRootUserName = "root";
  dgxSparkAdminGroup = "wheel";
  dgxSparkExpectedUid = 1555;
  dgxSparkExpectedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILYzh3yIsSTOYXkJMFHBKzkakoDfonm3/RED5rqMqhIO britton@framework"
  ];
  dgxSparkExcludedKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAX7hNDY0L9JSSIP+NVTbDluJgJ9c/l9nzbuwCNkVxgr britton@cproof.ai";
  dgxSparkEvaluatedConfig = (mkDgxSparkSystem dgxSparkRequiredSystem).config;
  dgxSparkUnsupportedConfig = (mkDgxSparkSystem dgxSparkUnsupportedSystem).config;
  dgxSparkPlatformAssertion = lib.findFirst (
    item: lib.hasPrefix "The DGX machine module requires" item.message
  ) null dgxSparkEvaluatedConfig.assertions;
  dgxSparkUnsupportedPlatformAssertion = lib.findFirst (
    item: lib.hasPrefix "The DGX machine module requires" item.message
  ) null dgxSparkUnsupportedConfig.assertions;
  dgxSparkUser = dgxSparkEvaluatedConfig.users.users.${dgxSparkUserName};
  dgxSparkRootUser = dgxSparkEvaluatedConfig.users.users.${dgxSparkRootUserName};
  dgxSparkUserKeys = dgxSparkUser.openssh.authorizedKeys.keys;
  dgxSparkRootKeys = dgxSparkRootUser.openssh.authorizedKeys.keys;
  dgxSparkSystemPackageNames = map lib.getName dgxSparkEvaluatedConfig.environment.systemPackages;
  dgxSparkAssertions = [
    {
      name = "positive: DGX Spark enables upstream hardware support on aarch64-linux";
      condition =
        dgxSparkEvaluatedConfig.hardware.dgx-spark.enable
        && dgxSparkEvaluatedConfig.services.openssh.enable
        && dgxSparkPlatformAssertion != null
        && dgxSparkPlatformAssertion.assertion;
    }
    {
      name = "positive: DGX Spark defines the brittonr administrator account";
      condition =
        dgxSparkUser.uid == dgxSparkExpectedUid
        && dgxSparkUser.isNormalUser
        && dgxSparkUser.group == dgxSparkUserName
        && builtins.elem dgxSparkAdminGroup dgxSparkUser.extraGroups;
    }
    {
      name = "positive: DGX Spark authorizes only approved keys for brittonr and root";
      condition = dgxSparkUserKeys == dgxSparkExpectedKeys && dgxSparkRootKeys == dgxSparkExpectedKeys;
    }
    {
      name = "positive: DGX Spark includes Sendme and Mesh-LLM";
      condition =
        builtins.elem "sendme" dgxSparkSystemPackageNames
        && builtins.elem "mesh-llm" dgxSparkSystemPackageNames;
    }
    {
      name = "negative: DGX Spark excludes the cproof.ai SSH key";
      condition =
        !builtins.elem dgxSparkExcludedKey dgxSparkUserKeys
        && !builtins.elem dgxSparkExcludedKey dgxSparkRootKeys;
    }
    {
      name = "negative: DGX Spark rejects unsupported host platforms";
      condition =
        dgxSparkUnsupportedPlatformAssertion != null
        && !dgxSparkUnsupportedPlatformAssertion.assertion
        &&
          dgxSparkUnsupportedPlatformAssertion.message
          == "The DGX machine module requires ${dgxSparkRequiredSystem}; got ${dgxSparkUnsupportedSystem}.";
    }
  ];
  failedDgxSparkAssertions = lib.filter (assertion: !assertion.condition) dgxSparkAssertions;
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

    dgx-spark-tag = pkgs.runCommand "dgx-spark-tag" { } ''
      ${lib.optionalString (failedDgxSparkAssertions != [ ]) ''
        echo "DGX Spark tag checks failed:" >&2
        printf '%s\n' ${lib.escapeShellArgs (map (assertion: assertion.name) failedDgxSparkAssertions)} >&2
        exit 1
      ''}
      touch $out
    '';
  };
}
