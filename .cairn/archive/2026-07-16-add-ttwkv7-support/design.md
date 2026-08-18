# Design: Add ttWKV7 support

## Context

Upstream builds one C++20 host executable and JIT-compiles five kernel source files at runtime. Its CMake project fetches a broad dependency graph through CPM and assumes a TT-Metal source build tree under `TT_METAL_HOME`. The pinned Onix TT-Metal package instead exports an installed `tt-metalium` CMake package with the `TT::Metalium` target and a separate runtime root at `libexec/tt-metalium`.

## Package architecture

`pkgs/ttwkv7/default.nix` will be the pure package description. It will:

1. Fetch the reviewed upstream revision with a fixed-output hash.
2. Patch only the build-system integration, replacing CPM and source-tree linkage with `find_package(tt-metalium CONFIG REQUIRED)` and `TT::Metalium`.
3. Build without network access against the pinned `tenstorrent.nix` `tt-metal` package.
4. Install the executable under `libexec`, copy the complete `kernels/` runtime source tree under `share/ttwkv7`, and create a thin wrapper that sets the matching Metalium runtime roots and changes to the immutable kernel-source directory before execution.

The package derivation remains deterministic logic; CMake, installation, and wrapper execution are the imperative shell. No runtime decision logic is hidden in the wrapper.

## Flake and host integration

`flake-outputs/ttwkv7.nix` exposes `packages.x86_64-linux.ttwkv7`, injects the pinned `tt-metal` derivation explicitly, and uses a package-specific unfree predicate without relaxing the repository's general package set. The `tenstorrent` inventory tag includes that package in `environment.systemPackages`, adds its executable/kernel layout to the existing native-runtime closure check, and documents the command.

## Validation

Positive checks will assert that both command aliases, the internal executable, and every required JIT kernel source are installed. A negative no-device check will invoke an invalid mode and require the upstream usage error, proving the wrapped executable and dynamic loader are functional without opening an accelerator. Nix evaluation and package build checks will cover flake exposure and offline construction.

Device execution is intentionally not part of build or activation. Upstream warns that repeated device creation can wedge a board, and the managed host has active model services with explicit device ownership.

## Compatibility and licensing boundary

Upstream identifies the implementation as Wormhole-targeted and publishes Wormhole benchmark results. Onix will not relabel that evidence as Blackhole support. The host guide will state that P150 execution is experimental until a manually isolated `wkv7 test` run passes and its TT-Metal logs are reviewed.

Because upstream currently has no license file or declared repository license, the package metadata will use the unfree classification. This does not infer redistribution rights.

## Rejected alternatives

- **Keep upstream CPM downloads:** rejected because sandboxed builds must not depend on network access.
- **Install only the executable:** rejected because runtime JIT compilation requires repository-relative kernel source paths.
- **Advertise P150 support after a successful build:** rejected because host compilation does not execute architecture-specific kernels.
- **Automatically run the device test:** rejected because it can conflict with managed model services and has board-reset risk.

## Requirements

- r[onix.tenstorrent.native_runtime.ttwkv7.package]
- r[onix.tenstorrent.native_runtime.ttwkv7.host]
- r[onix.tenstorrent.native_runtime.ttwkv7.compatibility_boundary]
