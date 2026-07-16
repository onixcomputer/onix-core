# Tasks: Add ttWKV7 support

- [x] [serial] Package the fixed ttWKV7 revision against the pinned installed TT-Metalium CMake target without build-time network access. r[onix.tenstorrent.native_runtime.ttwkv7.package]
- [x] [serial] Preserve the executable and all JIT kernel sources behind deterministic `wkv7` and `ttwkv7` wrappers. r[onix.tenstorrent.native_runtime.ttwkv7.package]
- [x] [serial] Expose the package on `x86_64-linux` and add it to Tenstorrent-tagged host closures. r[onix.tenstorrent.native_runtime.ttwkv7.host]
- [x] [serial] Add positive package-layout coverage and a negative no-device CLI validation case. r[onix.tenstorrent.native_runtime.ttwkv7.package]
- [x] [serial] Document invocation, unfree licensing, service-isolation expectations, and the Wormhole-versus-Blackhole compatibility boundary. r[onix.tenstorrent.native_runtime.ttwkv7.compatibility_boundary]
- [x] [serial] Run focused Nix evaluation, package build, lifecycle gates, and repository formatting checks. r[onix.tenstorrent.native_runtime.ttwkv7.host]
