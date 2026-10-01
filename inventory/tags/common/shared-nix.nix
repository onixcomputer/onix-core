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
  nixpkgs.overlays = [
    # Shared Onix packages (mesh-llm, lemonade-server, llamacpp-rocm-*, herdr, ...).
    inputs.onixpkgs.overlays.default
    (
      _final: _prev:
      {
        radicle-node = self.packages.${pkgs.stdenv.hostPlatform.system}.radicle-node or null;
        radicle-httpd = self.packages.${pkgs.stdenv.hostPlatform.system}.radicle-httpd or null;
      }
      // lib.optionalAttrs (_prev ? pkgsi686Linux) {
        # OpenLDAP's syncreplication integration test is flaky in the Nix
        # sandbox. Lutris' multiArch FHS root pulls the i686 package directly,
        # so skip only that runtime-library check instead of rebuilding native
        # OpenLDAP consumers.
        pkgsi686Linux = _prev.pkgsi686Linux.extend (
          _final32: prev32: {
            openldap = prev32.openldap.overrideAttrs (_old: {
              doCheck = false;
            });
          }
        );
      }
    )
    # Override nixVersions.latest with our wasm-enabled build so srvos
    # (which sets nix.package = nixVersions.latest) picks it up automatically.
    (
      _final: prev:
      let
        inherit (pkgs.stdenv.hostPlatform) system;
        onixNixPkgs = inputs.nix.packages.${system};
        onixNixComponents = {
          inherit (onixNixPkgs)
            nix-cli
            nix-cmd
            nix-expr
            nix-fetchers
            nix-flake
            nix-main
            nix-store
            ;
        };
        nixEvalJobsNix36Revision = "41235ab624bbb4e21c84ce30a76756921fe59f89";
        nixEvalJobsNix36Source = prev.fetchFromGitHub {
          owner = "NixOS";
          repo = "nix-eval-jobs";
          rev = nixEvalJobsNix36Revision;
          hash = "sha256-j72ybHHDR6b+abyBC+Dm1hSh6/ppllH3jO/dgahMixA=";
        };
      in
      {
        nixVersions = prev.nixVersions // {
          latest = onixNixPkgs.nix.overrideAttrs (_: {
            # Skip functional tests — the stale-file-handle overlayfs test
            # fails in sandbox. Tests are tracked upstream, not our concern.
            doCheck = false;
          });
        };

        # Rebuild nix-eval-jobs against the wasm-enabled Nix so buildbot
        # workers can evaluate builtins.wasm calls (Nickel plugin, YAML, etc).
        # Nix 2.36 changed derivation inputs and several flake APIs. Use the
        # reviewed upstream Nix 2.36 port until nixpkgs carries that source.
        nix-eval-jobs =
          (prev.nix-eval-jobs.override {
            nixComponents = onixNixComponents;
          }).overrideAttrs
            (old: {
              version = "2.36.0-unstable-2026-08-24";
              src = nixEvalJobsNix36Source;
              patches = (old.patches or [ ]) ++ [ ./nix-eval-jobs-2.36-release.patch ];
            });
      }
    )
    (_final: prev: {
      # nixpkgs' python dlib expression is stale against the 20.0.1 tarball
      # in two ways, and both break howdy's face-recognition dependency on
      # every nixpkgs that pairs dlib 20.0.1 with the old expression:
      #
      # 1. `build-cores.patch` no longer applies: upstream removed two
      #    trailing-whitespace bytes inside the hunk.
      # 2. 20.0.1's setup.py defers its `--set` argv stripping until
      #    build_extension runs, so setuptools rejects the `--set` flags
      #    that nixpkgs' preConfigure shim injects via setupPyBuildFlags.
      #
      # The overlay replaces the patch with the same change rebased onto
      # 20.0.1, bakes the cmake options into the cmake_args_dict literal
      # (same values the shim used to pass), and drops the shim. Remove this
      # whole override once upstream nixpkgs repairs the expression.
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
        (_python-final: python-prev: {
          dlib = python-prev.dlib.overrideAttrs (_old: {
            patches = [
              ./dlib-20.0.1-build-cores.patch
              ./dlib-20.0.1-cmake-args.patch
            ];
            preConfigure = "";
          });
        })
      ];
    })
    (_final: prev: {
      # GCC 16 compiles C++ as C++20, which deprecates the volatile-qualified
      # return type of Fv_Vi in ltrace's demangle test (-Wvolatile). DejaGnu
      # counts any compiler output as a failed test compile, so all of
      # demangle.exp fails and ltrace 0.7.91 no longer builds (Hydra build
      # 347155220). The return type is not part of the mangled name, so the
      # test still exercises the same symbol. Remove this override once
      # upstream nixpkgs builds ltrace with GCC 16.
      ltrace = prev.ltrace.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace testsuite/ltrace.minor/demangle.cpp \
            --replace-fail 'extern volatile int Fv_Vi(void);' 'extern int Fv_Vi(void);'
          substituteInPlace testsuite/ltrace.minor/demangle-lib.cpp \
            --replace-fail 'volatile int Fv_Vi(void)' 'int Fv_Vi(void)'
        '';
      });
    })
    (_final: prev: {
      # The zig 0.16.0 build on nixpkgs' GCC 16 stdenv writes compiler_rt.o
      # with .eh_frame FDEs against section symbols that have no section
      # (the previous zig 0.16.0 build did not). libghostty-vt bundles that
      # compiler_rt into its static archive, so herdr's link carries
      # zero-address FDEs and ld.bfd fails with ".eh_frame_hdr refers to
      # overlapping FDEs". Rust already links the compiler builtins, so stop
      # bundling Zig's runtimes on Linux, as nixpkgs' own herdr does
      # (NixOS/nixpkgs#568618). onixpkgs wraps this base binary as `herdr`.
      # Remove this override once llm-agents' herdr carries the same change.
      herdr-unwrapped = prev.herdr-unwrapped.overrideAttrs (old: {
        postPatch =
          (old.postPatch or "")
          + lib.optionalString prev.stdenv.hostPlatform.isLinux ''
            substituteInPlace vendor/libghostty-vt/src/build/GhosttyLibVt.zig \
              --replace-fail 'lib.bundle_compiler_rt = true;' 'lib.bundle_compiler_rt = false;' \
              --replace-fail 'lib.bundle_ubsan_rt = true;' 'lib.bundle_ubsan_rt = false;'
          '';
      });
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

      # Trigger GC mid-build when free space drops below 100 GiB;
      # stop collecting once 128 GiB is free.
      min-free = 107374182400;
      max-free = 137438953472;

      # Caches: flake.nixConfig provides nix-community.cachix.org;
      # additional caches are appended here so all machines share them.
      substituters = (flake.nixConfig.extra-substituters or [ ]) ++ [
        "https://cache.dataaturservice.se/spectrum/"
        # Disabled: snix daemon doesn't support Nix protocol 1.35 yet (HTTP 500)
        # "https://cache.snix.dev"
      ];
      trusted-public-keys = (flake.nixConfig.extra-trusted-public-keys or [ ]) ++ [
        "spectrum-os.org-2:foQk3r7t2VpRx92CaXb5ROyy/NBdRJQG2uX2XJMYZfU="
        # "cache.snix.dev-1:miTqzIzmCbX/DyK2tLNXDROk77CbbvcRdWA4y2F8pno="
      ];
    };
  };
}
