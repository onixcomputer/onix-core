# Tenstorrent Native Runtime Specification

## Purpose

Defines the `tenstorrent-native-runtime` capability.

## Requirements

### Requirement: Native Metalium packages
r[onix.tenstorrent.native_runtime.packages] A Tenstorrent-tagged host SHALL install the pinned native `tt-metal` and `llama-cpp-metalium` packages from the repository's `tenstorrent.nix` input.

#### Scenario: Required packages are present
- GIVEN a host with the `tenstorrent` inventory tag
- WHEN its NixOS system closure is evaluated
- THEN the closure includes both native runtime packages selected from the pinned input

#### Scenario: Required package disappears upstream
- GIVEN a pinned `tenstorrent.nix` package set missing either required package
- WHEN the Tenstorrent tag is evaluated
- THEN evaluation fails with a package-selection error instead of silently omitting native runtime support

### Requirement: P150x2 mesh environment
r[onix.tenstorrent.native_runtime.p150x2_mesh] The Tenstorrent host SHALL export Metalium runtime roots and `TT_MESH_GRAPH_DESC_PATH` for the shipped `p150_x2` descriptor representing one two-device Blackhole mesh with four relaxed channels.

#### Scenario: Native program opens the linked mesh
- GIVEN two p150a cards connected with two QSFP-DD cables and exposed as Tenstorrent device nodes
- WHEN a native Metalium program starts on the configured host
- THEN it receives the Nix-store Metalium root and P150x2 mesh descriptor through the system environment

#### Scenario: Descriptor path is malformed
- GIVEN a configuration whose descriptor filename is absent from the selected `tt-metal` output
- WHEN the native runtime layout check runs
- THEN the check fails before the configuration is treated as deployable

### Requirement: Manual firmware mutation boundary
r[onix.tenstorrent.native_runtime.firmware_boundary] The Tenstorrent configuration MUST NOT flash device firmware automatically during build, activation, boot, or native runtime startup.

#### Scenario: System configuration changes
- GIVEN a newer firmware bundle is packaged by Nix
- WHEN the system is rebuilt or rebooted
- THEN the cards retain their current firmware until an operator explicitly runs the reviewed flash command

#### Scenario: Runtime firmware is incompatible
- GIVEN card firmware that does not satisfy the selected native runtime
- WHEN the operator performs native runtime verification
- THEN verification stops with a compatibility blocker rather than initiating an automatic flash

### Requirement: P150x2 identity remains explicit
r[onix.tenstorrent.native_runtime.identity] Operator documentation MUST identify the linked cards as P150x2 and MUST NOT recommend the TT-Inference-Server `p300` target as an alias for two separate p150 boards.

#### Scenario: Operator follows native instructions
- GIVEN two linked p150a cards
- WHEN the operator reads the generated Tenstorrent host documentation
- THEN the instructions select the P150x2 mesh descriptor and explain the current inference-server catalog limitation

#### Scenario: Operator considers the P300 target
- GIVEN a two-chip `p300` inference-server entry
- WHEN the operator compares it with the installed hardware
- THEN the documentation states that P300 is a distinct dual-die board and does not claim compatibility through naming alone

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

### Requirement: ttWKV7 single-device topology isolation
r[onix.tenstorrent.native_runtime.ttwkv7.single_device_topology] The packaged ttWKV7 command MUST clear any inherited `TT_MESH_GRAPH_DESC_PATH` before TT-Metal device creation so its unit mesh is derived from the operator-selected visible device rather than the host's linked-card topology.

#### Scenario: Host exports a linked-card mesh descriptor
- GIVEN a Tenstorrent host exports the P150x2 mesh graph descriptor
- WHEN an operator invokes packaged ttWKV7 with one physical card selected through `TT_VISIBLE_DEVICES`
- THEN the wrapper removes the inherited mesh descriptor before launching the executable
- AND TT-Metal is not asked to map the two-card graph onto the one-card visible topology

#### Scenario: Wrapper topology isolation regresses
- GIVEN the generated ttWKV7 wrapper
- WHEN package validation inspects its environment mutations
- THEN validation fails if the wrapper does not explicitly unset `TT_MESH_GRAPH_DESC_PATH`
- AND validation fails if the wrapper exports a replacement mesh descriptor value

### Requirement: ttWKV7 architecture-selected SFPU lifecycle
r[onix.tenstorrent.native_runtime.ttwkv7.architecture_sfpu] The packaged ttWKV7 constant-tile generators MUST preserve the pinned Metalium runtime's architecture-specific SFPU start and finalization semantics instead of invoking a Wormhole-only address-modifier primitive directly or assuming one common finalizer has equivalent effects on every architecture.

#### Scenario: Blackhole preserves the required reset
- GIVEN the packaged ttWKV7 chunked and decode constant generators and the pinned Blackhole Metalium LLK
- WHEN TT-Metal JIT-compiles either generator for a P150
- THEN SFPU setup resolves through the Blackhole start helper
- AND finalization uses the Blackhole helper that waits for SFPU completion and resets C16
- AND the source does not require `math::set_addr_mod_base()`

#### Scenario: Wormhole cleanup remains delegated to Metalium
- GIVEN the packaged ttWKV7 chunked and decode constant generators and the pinned Wormhole Metalium LLK
- WHEN TT-Metal JIT-compiles either generator for Wormhole
- THEN setup and finalization resolve through the Wormhole helpers
- AND ttWKV7 does not duplicate Wormhole address-modifier setup or cleanup

#### Scenario: Architecture lifecycle regression is detected
- GIVEN the installed ttWKV7 kernel sources
- WHEN package validation inspects their SFPU lifecycle
- THEN validation requires the reviewed Blackhole and Wormhole helper branches
- AND validation fails if either generator contains the direct Wormhole-only primitive

### Requirement: ttWKV7 exact constant-tile probe
r[onix.tenstorrent.native_runtime.ttwkv7.constant_tile_probe] The packaged ttWKV7 diagnostics MUST provide a bounded single-device probe that, after successful runtime initialization, compares every generated chunked constant tile exactly against a pure CPU oracle without running the WKV recurrence, and MUST fail nonzero without claiming a mask result when runtime initialization prevents that comparison.

#### Scenario: Pure oracle accepts reviewed boundary cases
- GIVEN each of the seven chunked constant patterns and reviewed lengths 1 and 32
- WHEN the no-device self-test generates expected 32-by-32 tiles
- THEN every element matches the pattern's logical row and column predicate
- AND the self-test succeeds without creating a Tenstorrent device

#### Scenario: Pure oracle rejects invalid inputs
- GIVEN an unknown constant pattern or a length outside the inclusive range 1 through 32
- WHEN the pure oracle validates the request
- THEN it rejects the request deterministically
- AND the shell returns a nonzero status without creating a Tenstorrent device

#### Scenario: P150 diagnostic reaches mask comparison
- GIVEN device 1 is isolated from its owning service, selected as the only visible device, and Metalium runtime diagnostics have writable storage
- WHEN the operator invokes the packaged constant-tile probe once and runtime initialization succeeds
- THEN one device open emits all seven patterns for lengths 1 and 32
- AND every BF16 element is compared exactly with a first-mismatch and total-mismatch diagnostic
- AND no WKV recurrence or automatic retry executes

#### Scenario: Runtime initialization blocker fails closed
- GIVEN device 1 is isolated and the packaged probe cannot initialize a required Metalium runtime evidence path
- WHEN the operator invokes the probe once
- THEN the process returns nonzero without reporting any mask as passing
- AND the one-run budget is treated as exhausted rather than retried automatically

#### Scenario: Probe result does not overstate support
- GIVEN all reviewed constant tiles pass or any tile fails
- WHEN the compatibility boundary is documented
- THEN the result is limited to the tested package, architecture, patterns, and lengths
- AND it does not claim general P150 WKV numerical compatibility

### Requirement: ttWKV7 focused diagnostic iteration
r[onix.tenstorrent.native_runtime.ttwkv7.fast_iteration] Onix MUST provide a focused ttWKV7 package lane that independently caches compiled host executables, immutable runtime JIT kernels, and lightweight wrappers while retaining a composed exact Nix store output for final validation.

#### Scenario: Runtime-only change reuses host binaries
- GIVEN unchanged pinned upstream host sources and Metalium dependencies
- WHEN an operator changes only a runtime wrapper or packaged JIT kernel
- THEN the compiled host-executable derivation identity remains unchanged
- AND the composed package receives a new immutable identity for the changed runtime content

#### Scenario: Exact package runs without profile activation
- GIVEN an exact reviewed ttWKV7 package output exists in the managed host's Nix store
- WHEN an operator prepares a separately authorized diagnostic
- THEN the operator can invoke that exact store output without first activating a new NixOS generation
- AND the full machine closure remains a required final integration gate rather than an inner-loop prerequisite

#### Scenario: Architecture checks remain device-free
- GIVEN the pinned Metalium SFPI compiler and packaged ttWKV7 compute kernels
- WHEN the focused architecture check runs for Blackhole and Wormhole
- THEN every reviewed compute kernel produces a compiler object for both architecture configurations
- AND the check does not enumerate, open, reset, or communicate with a Tenstorrent device

#### Scenario: Focused checks reject incomplete composition
- GIVEN a composed package missing a required executable, kernel, architecture helper, or safe wrapper behavior
- WHEN package validation runs
- THEN validation fails deterministically
- AND no Tenstorrent device is created

### Requirement: ttWKV7 explicit runtime state
r[onix.tenstorrent.native_runtime.ttwkv7.explicit_runtime_state] The packaged ttWKV7 constant-tile probe MUST fail before device initialization unless probe mode receives explicit absolute writable Metalium cache and log directories plus an explicit loopback Inspector RPC address.

#### Scenario: Runtime preflight accepts isolated evidence paths
- GIVEN absolute cache and log paths that can be created or written and a loopback Inspector address with a valid TCP port
- WHEN the operator invokes the no-device runtime preflight
- THEN the wrapper prepares both directories and returns success
- AND no Tenstorrent device is created

#### Scenario: Runtime preflight rejects unsafe state
- GIVEN a missing path, relative path, non-directory path, non-loopback Inspector host, or out-of-range Inspector port
- WHEN the operator invokes runtime preflight or probe mode
- THEN the wrapper returns nonzero before executing the device-owning probe binary
- AND it does not report a mask result

#### Scenario: Explicit state does not authorize hardware
- GIVEN runtime preflight passes for an exact package output
- WHEN no separate hardware authorization has been granted
- THEN the operator does not invoke probe mode
- AND the wrapper does not stop services, select devices, retry, or claim compatibility by itself
