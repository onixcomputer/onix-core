# Tenstorrent Native Runtime Delta

## ADDED Requirements

### Requirement: Reproducible ttWKV7 package
r[onix.tenstorrent.native_runtime.ttwkv7.package] Onix SHALL provide an `x86_64-linux` ttWKV7 package from a fixed upstream revision, built without network access against the repository's pinned TT-Metalium package, with the host executable and every runtime JIT kernel source installed together.

#### Scenario: Package builds from pinned inputs
- GIVEN the fixed ttWKV7 source and the pinned `tenstorrent.nix` TT-Metalium package
- WHEN the `ttwkv7` flake package is built in the Nix sandbox
- THEN CMake resolves the installed `TT::Metalium` target without fetching dependencies from the network
- AND the output contains the wrapped command, internal executable, and all required JIT kernel sources

#### Scenario: Runtime kernel source is omitted
- GIVEN a candidate ttWKV7 output missing any required reader, compute, or writer kernel source
- WHEN the package layout validation runs
- THEN the build fails instead of publishing an executable that cannot JIT-compile its kernels

#### Scenario: Invalid command avoids device access
- GIVEN the wrapped ttWKV7 executable on a host without an acquired accelerator
- WHEN the validation invokes an unsupported command mode
- THEN the command returns its usage error before attempting to create a Metalium device

### Requirement: Tenstorrent host availability
r[onix.tenstorrent.native_runtime.ttwkv7.host] A Tenstorrent-tagged Onix host SHALL include the pinned ttWKV7 package in its system closure and document the stable `wkv7` invocation path.

#### Scenario: Operator uses a Tenstorrent host
- GIVEN a NixOS machine with the `tenstorrent` inventory tag
- WHEN its system closure and generated host guide are evaluated
- THEN the closure contains the `ttwkv7` package
- AND the guide identifies the packaged `wkv7 test` and `wkv7 bench` commands

#### Scenario: Package disappears from the host closure
- GIVEN a Tenstorrent-tagged configuration that no longer installs the `ttwkv7` package
- WHEN the native runtime layout check runs
- THEN validation fails instead of silently dropping the operator command

### Requirement: Hardware and licensing claim boundary
r[onix.tenstorrent.native_runtime.ttwkv7.compatibility_boundary] Onix MUST classify ttWKV7 as unfree while upstream declares no license and MUST state that reproducible packaging does not establish Blackhole P150 compatibility for an upstream Wormhole-targeted kernel.

#### Scenario: P150 operator reviews support status
- GIVEN the managed host contains Blackhole P150 accelerators
- WHEN the operator reads the generated Tenstorrent guide before running ttWKV7
- THEN the guide identifies upstream's Wormhole target
- AND it requires a manually isolated device test before making a P150 runtime claim

#### Scenario: Package metadata is reviewed
- GIVEN the pinned upstream revision has no license declaration
- WHEN package metadata is evaluated
- THEN the package uses an unfree license classification instead of inferring redistribution permission
