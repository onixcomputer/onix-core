## Why

onix-core defined 42 portable packages under `pkgs/` and exposed them three ways: as flake `packages`, through `pkgs.callPackage ../../pkgs/<name> { }` in modules and profiles, and through an internal overlay in `inventory/tags/common/shared-nix.nix` that injected seven of them from `self.packages`. Other stack repositories copied or reached into these definitions: site copies `pkgs/celld`, aspen imports `pkgs/kache` from a pinned onix-core source input, and trellis rebuilds tracey. onixpkgs (`/home/brittonr/git/OnixResearch/onixpkgs`, change `establish-shared-package-overlay`) now owns these packages as an overlay over nixpkgs.

## What Changes

- Add the `onixpkgs` input. It follows onix-core's `nixpkgs`, `llm-agents`, `wrappers`, and `treefmt-nix`, and takes over the `horizon` source input.
- Apply `onixpkgs.overlays.default` to every NixOS and darwin machine in `shared-nix.nix`, replacing the seven `self.packages` injections. `modules/dgx-machine` applies it for DGX devenv machines, and `flake-outputs/checks.nix` applies it to check harnesses.
- Replace every `pkgs.callPackage ../../pkgs/<name>` and `self.packages.<system>.<name>` reference to a migrated package with `pkgs.<name>`. The dev shell uses `inputs'.onixpkgs.<name>`.
- Delete the 42 migrated package directories and their four patches from `pkgs/` and `patches/`. Keep dgx-machine, tenstorrent-compat, nix-grpc-store, and aspen-uma-helper.
- Move the Collie Home Manager integration check to `flake-outputs/_collie-herdr-integration-check.nix`. The package-level Collie tests run in onixpkgs.
- Remove obsolete references: treefmt excludes for the vendored Herdr and Collie trees, the pytest `norecursedirs` entry, the vcrpy test dependencies, and the lemonade packaging note, which moved to onixpkgs.

## Impact

- **Files**: `flake.nix`, `flake.lock`, `inventory/tags/common/shared-nix.nix`, 11 module files, 6 Home Manager profiles, `inventory/tags/media.nix`, `machines/aspen3` and `machines/britton-desktop`, `flake-outputs/{tools,dev-env,checks,_home-manager-checks,_module-checks,_mesh-llm-checks,_radicle-ci-runner-checks,_collie-herdr-integration-check}.nix`, `pkgs/`, `patches/`, `README.md`, `AGENTS.md`, `docs/branchfs.md`, and `pyproject.toml`.
- **Testing**: evaluate every machine toplevel, every x86_64-linux check, the dev shells, and the exported packages before and after the change, and explain each derivation difference. Validate this change with Cairn.
- **Operations**: no deployment is part of this change. The `onixpkgs` input fetches `github.com/OnixResearch/onixpkgs` over SSH, like onix-core's other OnixResearch inputs.
