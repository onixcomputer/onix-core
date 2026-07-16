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

### Requirement: ttWKV7 one-shot constant-tile measurement
r[onix.tenstorrent.native_runtime.ttwkv7.constant_tile_measurement] An authorized ttWKV7 constant-tile measurement MUST bind one exact package output, immutable kernel target, isolated physical device, explicit writable runtime state, owner-restoration trap, hard timeout, and invocation count before executing probe mode, and MUST treat the first process result as exhausting the change's hardware budget.

#### Scenario: Offline review does not consume authorization
- GIVEN an exact reviewed package and proposed runtime-state paths
- WHEN package checks, architecture compilation, path capture, and runtime preflight execute
- THEN no Tenstorrent device is created by those checks
- AND the physical invocation count remains zero

#### Scenario: Owner isolation precedes the one invocation
- GIVEN device 1 has an active owning service before the reviewed run
- WHEN the physical probe phase begins
- THEN the prior active state is recorded and the owner is stopped
- AND probe mode does not execute unless the owner is proven inactive

#### Scenario: First process result exhausts the budget
- GIVEN owner isolation succeeded and the exact package, runtime state, device selection, and timeout match the reviewed change
- WHEN probe mode is invoked
- THEN the invocation count changes from zero to one before process execution
- AND success, mask mismatch, initialization failure, signal, or timeout terminates the physical search without retry

#### Scenario: Prior owner state is restored
- GIVEN the owner service was active before isolation
- WHEN the probe exits for any ordinary process status or the orchestration shell terminates
- THEN an exit trap attempts to restart the owner exactly once
- AND post-run service, endpoint, and board-health evidence is retained

#### Scenario: Measurement remains narrowly scoped
- GIVEN the fourteen reviewed masks pass exactly or any terminal failure occurs
- WHEN the outcome is documented
- THEN the claim is limited to the exact package, kernel target, selected P150, patterns, and lengths
- AND no full-WKV correctness, decode correctness, performance, or general P150 compatibility is inferred

### Requirement: ttWKV7 least-privilege owner control
r[onix.tenstorrent.native_runtime.ttwkv7.owner_control] The managed Blackhole host MUST provide an immutable non-interactive owner-control interface whose privileged capability is limited to starting and stopping the exact device-1 owner unit and inspecting open files for the exact device-1 path, without granting probe execution or broader root authority.

#### Scenario: Exact capabilities validate without service mutation
- GIVEN the activated owner-control wrapper and sudo policy
- WHEN the operator invokes validation mode
- THEN passwordless permission exists for the exact owner start, owner stop, and device ownership inspection commands
- AND validation does not stop or start the owner or access a Tenstorrent device

#### Scenario: Isolation fails closed
- GIVEN the exact owner is active before isolation
- WHEN the operator invokes isolation mode
- THEN the wrapper stops the owner once and proves it inactive
- AND any failed inactive-state or open-owner check attempts to restore the owner before returning nonzero

#### Scenario: Restoration targets only the prior owner
- GIVEN a reviewed caller must restore device 1 after its bounded operation
- WHEN the caller invokes restore mode from its exit trap
- THEN the wrapper starts only the exact device-1 owner unit
- AND it proves that unit active before returning success

#### Scenario: Broad privileged commands remain denied
- GIVEN the evaluated passwordless command set for the owner-control user
- WHEN machine validation inspects its command paths and arguments
- THEN no wildcard systemctl, restart, unrelated unit, arbitrary device, or all-command permission is present
- AND unsupported wrapper modes or extra arguments fail before sudo executes

#### Scenario: Owner control does not authorize a probe
- GIVEN validation or isolation succeeds
- WHEN no separate reviewed hardware authorization exists
- THEN the wrapper does not invoke ttWKV7, select a device, create runtime state, retry, or claim compatibility
- AND the operator does not execute a hardware probe

### Requirement: ttWKV7 NixOS sudo trampoline
r[onix.tenstorrent.native_runtime.ttwkv7.owner_control.sudo_wrapper] The managed ttWKV7 owner-control helper MUST invoke sudo through the root-managed NixOS setuid wrapper at `/run/wrappers/bin/sudo`, MUST NOT invoke a raw Nix store sudo executable, and MUST preserve the argument-exact privileged target commands defined by the owner-control policy.

#### Scenario: Exact grants validate on the activated host
- GIVEN the reviewed sudoers policy is activated
- WHEN the operator runs `ttwkv7-owner-control validate`
- THEN validation succeeds through `/run/wrappers/bin/sudo`
- AND no service state changes
- AND no Tenstorrent device is accessed

#### Scenario: Raw store sudo regresses
- GIVEN the generated immutable owner-control helper
- WHEN device-free package validation inspects its command composition
- THEN validation fails if the helper references `${pkgs.sudo}/bin/sudo` or another raw store sudo executable
- AND validation fails if the canonical NixOS sudo wrapper path is absent

#### Scenario: Unauthorized lifecycle command is attempted
- GIVEN the activated owner-control sudo policy
- WHEN the operator requests restart or another unreviewed systemctl argument vector non-interactively
- THEN sudo rejects the command
- AND the owner service remains active and healthy

### Requirement: ttWKV7 independently restored one-shot measurement
r[onix.tenstorrent.native_runtime.ttwkv7.constant_tile_measurement.timed_restore] An authorized ttWKV7 constant-tile measurement MUST arm an independently surviving timed owner restoration before isolation, MUST preserve ordinary exit-trap restoration, MUST bind one exact package, kernel, device, runtime state, timeout, and invocation count, and MUST treat the first probe process result as exhausting the change's hardware budget.

#### Scenario: Offline review preserves authorization
- GIVEN an exact package, owner-control helper, rollback command, and proposed runtime state
- WHEN lifecycle gates, package checks, architecture compilation, shell review, and runtime preflight execute
- THEN no Tenstorrent device is created by those checks
- AND the physical invocation count remains zero

#### Scenario: Runbook launchability precedes orchestration
- GIVEN a committed one-shot runbook and zero invocation count
- WHEN the reviewed launch boundary is validated
- THEN executable mode is proven before the orchestration command is started
- AND an exec failure terminates the change without an alternate launch command or retry

#### Scenario: Rollback must arm before isolation
- GIVEN the owner service is active and healthy
- WHEN the authorized physical phase begins
- THEN the named independent rollback timer is armed and proven active before owner isolation
- AND failure to arm the timer prevents owner stop and probe invocation

#### Scenario: Ordinary or abrupt orchestration loss restores ownership
- GIVEN the owner was active before successful isolation
- WHEN the probe exits normally, fails, times out, or the orchestration process terminates
- THEN the exit trap attempts immediate restoration when it runs
- AND the independent timer remains able to start the exact owner unit if the trap does not run

#### Scenario: First process result exhausts the budget
- GIVEN isolation succeeded and all exact metadata still matches
- WHEN probe mode is invoked
- THEN the invocation count changes from zero to one immediately before execution
- AND success, mismatch, initialization failure, signal, or timeout terminates the physical search without retry

#### Scenario: Exact output limits the claim
- GIVEN the probe returns any terminal result
- WHEN evidence is classified
- THEN validation requires all fourteen exact comparisons and the final pass marker
- AND no full-WKV correctness, performance, decode correctness, or general P150 compatibility is inferred

### Requirement: ttWKV7 executable one-shot boundary
r[onix.tenstorrent.native_runtime.ttwkv7.constant_tile_measurement.executable_runbook] A newly authorized ttWKV7 measurement MUST use a fresh runbook committed with executable mode, MUST prove direct launchability before owner isolation, MUST preserve independently timed and exit-trap restoration, and MUST consume at most one exact probe process result without interpreter fallback or retry.

#### Scenario: Executable mode is reviewed before launch
- GIVEN a fresh committed one-shot runbook and zero invocation count
- WHEN offline review completes
- THEN filesystem launchability and Git mode `100755` are proven
- AND direct negative execution reaches the runbook's argument rejection path

#### Scenario: Launchability regression fails closed
- GIVEN the committed runbook lacks executable mode or direct invocation fails before its argument guard
- WHEN the orchestration boundary is reached
- THEN no owner isolation or probe invocation occurs
- AND the change terminates without interpreter fallback, chmod repair, or retry

#### Scenario: Production wrapper target is immutable and executable
- GIVEN the composed package's device probe wrapper
- WHEN offline launchability validation inspects its exec target
- THEN the target is an existing absolute immutable executable
- AND validation rejects an unexpanded runtime `$out` reference or a fake-only target check

#### Scenario: Rollback precedes owner isolation
- GIVEN the owner is active and healthy and all launchability checks pass
- WHEN the authorized physical phase begins
- THEN the named independent rollback timer is active before owner isolation
- AND the exit trap retains ordinary immediate restoration

#### Scenario: One process exhausts authorization
- GIVEN exact metadata, isolation, device ownership, and runtime state are proven
- WHEN probe mode starts
- THEN invocation count changes from zero to one immediately before the process
- AND every process result terminates the physical search without retry

#### Scenario: Exact evidence bounds compatibility claims
- GIVEN any terminal probe result
- WHEN evidence is classified
- THEN validated success requires fourteen unique exact comparisons plus the final pass marker
- AND no full-WKV, decode, performance, or general P150 compatibility claim is inferred
