## ADDED Requirements

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
