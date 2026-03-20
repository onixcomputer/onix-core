# Shared Nix daemon settings for both NixOS and Darwin.
# Uses _class to handle platform differences (GC schedule syntax, package names).
#
# Adapted from clan-infra modules/nix-daemon.nix.
{
  _class,
  lib,
  self,
  inputs,
  pkgs,
  ...
}:
let
  flake = import "${self}/flake.nix";
in
{
  # Override nixVersions.latest with our wasm-enabled build so srvos
  # (which sets nix.package = nixVersions.latest) picks it up automatically.
  nixpkgs.overlays = [
    (_final: _prev: {
      llamacpp-rocm-rpc = self.packages.${pkgs.stdenv.hostPlatform.system}.llamacpp-rocm-rpc or null;
    })
    (_final: prev: {
      nixVersions = prev.nixVersions // {
        latest = inputs.nix-wasm.packages.${pkgs.stdenv.hostPlatform.system}.nix.overrideAttrs (_: {
          # Skip functional tests — the stale-file-handle overlayfs test
          # fails in sandbox. Tests are tracked upstream, not our concern.
          doCheck = false;
        });
      };

      # FIXME: remove after nixpkgs updates past the electron 39.8.2 patch failure.
      # The 39-angle-patchdir.patch context drifted; replace with sed.
      # The sed must run before postPatch's apply_all_patches loop reads config.json,
      # so we also drop the original patch from the patches list to avoid the patchPhase error.
      electron_39 = prev.electron_39.override {
        electron-unwrapped = prev.electron_39.unwrapped.overrideAttrs (old: {
          patches = builtins.filter (p: !(lib.hasSuffix "39-angle-patchdir.patch" (toString p))) (
            old.patches or [ ]
          );
          postPatch =
            lib.replaceStrings
              [ "config=src/electron/patches/config.json" ]
              [
                ''
                  config=src/electron/patches/config.json
                  # Fix angle repo path (replaces 39-angle-patchdir.patch whose context drifted)
                  sed -i 's|"repo": "src/third_party/angle/src"|"repo": "src/third_party/angle"|' "$config"
                ''
              ]
              (old.postPatch or "");
        });
      };
    })
  ];

  nix = {
    # GC: both platforms, different schedule syntax
    gc = {
      automatic = lib.mkDefault true;
      options = lib.mkDefault "--delete-older-than 30d";
    }
    // lib.optionalAttrs (_class == "nixos") {
      dates = lib.mkDefault "weekly";
    }
    // lib.optionalAttrs (_class == "darwin") {
      interval = [
        {
          Weekday = 0;
          Hour = 2;
          Minute = 0;
        }
      ];
    };

    # Pin legacy <nixpkgs> to the flake input so `nix-shell -p foo` and
    # `import <nixpkgs>` use our pinned nixpkgs, not stale channels.
    nixPath = [ "nixpkgs=flake:nixpkgs" ];

    optimise.automatic = true;

    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
        "wasm-builtin"
      ];
      trusted-users = [
        "root"
        "@wheel"
      ];
      keep-outputs = true;
      keep-derivations = true;
      warn-dirty = false;
      auto-optimise-store = true;

      # Trust signing keys from flake config if present
      substituters = flake.nixConfig.extra-substituters or [ ];
      trusted-public-keys = flake.nixConfig.extra-trusted-public-keys or [ ];
    };
  };
}
