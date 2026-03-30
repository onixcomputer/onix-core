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
    (
      _final: prev:
      let
        inherit (pkgs.stdenv.hostPlatform) system;
        wasmNixPkgs = inputs.nix-wasm.packages.${system};
        wasmNixComponents = {
          inherit (wasmNixPkgs)
            nix-cli
            nix-cmd
            nix-expr
            nix-fetchers
            nix-flake
            nix-main
            nix-store
            ;
        };
      in
      {
        nixVersions = prev.nixVersions // {
          latest = wasmNixPkgs.nix.overrideAttrs (_: {
            # Skip functional tests — the stale-file-handle overlayfs test
            # fails in sandbox. Tests are tracked upstream, not our concern.
            doCheck = false;
          });
        };

        # Rebuild nix-eval-jobs against the wasm-enabled Nix so buildbot
        # workers can evaluate builtins.wasm calls (Nickel plugin, YAML, etc).
        # Pin to v2.33.1 to match our Nix 2.33.3 — the nixpkgs default
        # (v2.34.1) is built against Nix 2.34 and ABI-incompatible.
        nix-eval-jobs =
          (prev.nix-eval-jobs.override {
            nixComponents = wasmNixComponents;
          }).overrideAttrs
            (_: {
              version = "2.33.1";
              src = prev.fetchFromGitHub {
                owner = "nix-community";
                repo = "nix-eval-jobs";
                tag = "v2.33.1";
                hash = "sha256-ONA7ztgyE2CC3T45NiGxQgCBQevAJ1+pEJlMQpREjBA=";
              };
            });
      }
    )
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
