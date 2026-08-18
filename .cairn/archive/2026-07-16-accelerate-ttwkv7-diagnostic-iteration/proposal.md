## Why

The ttWKV7 diagnostic loop currently couples host-binary compilation, immutable JIT kernels, runtime wrappers, the full `britton-desktop` closure, and NixOS activation. Wrapper-only or kernel-only changes therefore repeat unrelated work and can encounter Clan/SOPS activation failures before reaching the diagnostic. The last authorized probe also demonstrated that implicit Metalium runtime paths can direct mutable evidence into the read-only package working directory.

## What Changes

- Split the ttWKV7 package into independently cached host binaries, immutable kernel sources, and lightweight runtime wrappers.
- Require explicit writable Metalium cache/log paths and a loopback Inspector address before device probe mode can execute.
- Add focused no-device package checks and pinned Blackhole/Wormhole math-kernel compilation checks.
- Keep the root Onix flake and host integration in this repository, but decompose the monolithic Tenstorrent tag behind its existing discoverable `.nix` shim.
- Permit reviewed diagnostics to execute an exact Nix store package without a NixOS activation; retain the full machine closure as a final integration gate.
- Do not deploy, access a Tenstorrent device, or consume a hardware-run authorization in this change.

## Impact

- **Files**: `pkgs/ttwkv7/`, `flake-outputs/ttwkv7.nix`, `inventory/tags/tenstorrent.nix`, `inventory/tags/tenstorrent/`, focused checks, and Tenstorrent lifecycle specifications.
- **Testing**: Cairn gates, package and negative runner checks, Blackhole/Wormhole offline math-kernel compilation, accelerator inventory, full `britton-desktop` closure, and repository formatting; no hardware execution.
