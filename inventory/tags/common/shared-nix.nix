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

      # Caches: flake.nixConfig provides nix-community.cachix.org;
      # additional caches are appended here so all machines share them.
      substituters = (flake.nixConfig.extra-substituters or [ ]) ++ [
        "https://cache.dataaturservice.se/spectrum/"
        "https://cache.snix.dev"
      ];
      trusted-public-keys = (flake.nixConfig.extra-trusted-public-keys or [ ]) ++ [
        "spectrum-os.org-2:foQk3r7t2VpRx92CaXb5ROyy/NBdRJQG2uX2XJMYZfU="
        "cache.snix.dev-1:miTqzIzmCbX/DyK2tLNXDROk77CbbvcRdWA4y2F8pno="
      ];
    };
  };
}
