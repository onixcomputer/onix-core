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
- WHEN an operator prepares a reviewed diagnostic
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

#### Scenario: Runtime preflight remains non-orchestrating
- GIVEN runtime preflight passes for an exact package output
- WHEN the operator invokes preflight without launching probe mode
- THEN no owner service is stopped and no Tenstorrent device is selected or initialized
- AND the wrapper does not retry or claim compatibility by itself

### Requirement: ttWKV7 one-shot constant-tile measurement
r[onix.tenstorrent.native_runtime.ttwkv7.constant_tile_measurement] A ttWKV7 constant-tile measurement MUST bind one exact package output, immutable kernel target, isolated physical device, explicit writable runtime state, owner-restoration trap, hard timeout, and invocation count before executing probe mode, and MUST treat the first process result as exhausting the change's hardware budget.

#### Scenario: Offline review remains device-free
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

#### Scenario: Owner control does not invoke a probe
- GIVEN the operator invokes validation, isolation, or restoration mode
- WHEN the owner-control operation completes
- THEN the wrapper does not invoke ttWKV7, select a device, create runtime state, retry, or claim compatibility
- AND probe execution remains a separate immutable runbook action

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
r[onix.tenstorrent.native_runtime.ttwkv7.constant_tile_measurement.timed_restore] A ttWKV7 constant-tile measurement MUST arm an independently surviving timed owner restoration before isolation, MUST preserve ordinary exit-trap restoration, MUST bind one exact package, kernel, device, runtime state, timeout, and invocation count, and MUST treat the first probe process result as exhausting the change's hardware budget.

#### Scenario: Offline review remains device-free
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
- WHEN the physical phase begins
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
r[onix.tenstorrent.native_runtime.ttwkv7.constant_tile_measurement.executable_runbook] A fresh ttWKV7 measurement MUST use a runbook committed with executable mode, MUST prove direct launchability before owner isolation, MUST preserve independently timed and exit-trap restoration, and MUST consume at most one exact probe process result without interpreter fallback or retry.

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
- WHEN the physical phase begins
- THEN the named independent rollback timer is active before owner isolation
- AND the exit trap retains ordinary immediate restoration

#### Scenario: One process exhausts the one-shot budget
- GIVEN exact metadata, isolation, device ownership, and runtime state are proven
- WHEN probe mode starts
- THEN invocation count changes from zero to one immediately before the process
- AND every process result terminates the physical search without retry

#### Scenario: Exact evidence bounds compatibility claims
- GIVEN any terminal probe result
- WHEN evidence is classified
- THEN validated success requires fourteen unique exact comparisons plus the final pass marker
- AND no full-WKV, decode, performance, or general P150 compatibility claim is inferred

### Requirement: ttWKV7 immutable production probe wrapper
r[onix.tenstorrent.native_runtime.ttwkv7.production_probe_wrapper] The composed ttWKV7 package MUST embed an existing absolute immutable probe-runtime executable at build time, MUST NOT resolve its target from a caller-controlled runtime `out` variable, and MUST validate production dispatch without creating a Tenstorrent device.

#### Scenario: Production dispatch ignores caller output state
- GIVEN the composed package's actual probe wrapper and pinned no-device self-test
- WHEN package validation runs with `out` absent and with `out` set to a hostile nonexistent path
- THEN both executions reach and pass the immutable production probe self-test
- AND neither execution initializes a Tenstorrent device

#### Scenario: Embedded target is exact and executable
- GIVEN the generated production probe wrapper
- WHEN package validation inspects its dispatch statement
- THEN the embedded target is an absolute path under the composed package's Nix store output
- AND the target exists and is executable

#### Scenario: Probe mode is preserved across runtime validation
- GIVEN the production wrapper receives `probe` plus zero or more forwarded probe arguments
- WHEN runtime-state validation succeeds and dispatch occurs
- THEN the immutable runtime binary receives `probe` as its first mode argument
- AND package validation rejects dropping, duplicating, or reordering that mode

#### Scenario: Runtime output expansion regresses
- GIVEN a candidate production wrapper containing an unexpanded `$out` target or validation that exercises only a fake probe
- WHEN package validation runs
- THEN validation fails before publication
- AND no hardware result or compatibility claim is inferred

### Requirement: ttWKV7 post-wrapper-repair one-shot measurement
r[onix.tenstorrent.native_runtime.ttwkv7.constant_tile_measurement.wrapper_repair] A fresh post-repair ttWKV7 measurement MUST bind the verified immutable production wrapper, exact package and kernels, isolated device 1, explicit writable runtime state, independently timed and exit-trap restoration, and zero invocation count before consuming exactly one probe process result without fallback or retry.

#### Scenario: Repaired wrapper is proven before isolation
- GIVEN a fresh package output and committed executable runbook
- WHEN device-free review completes
- THEN the production wrapper's immutable target, no-device dispatch, runbook mode, exact metadata, runtime state, and rollback mechanism all pass
- AND invocation, service-stop, and rollback-arm counts remain zero

#### Scenario: One repaired process exhausts the one-shot budget
- GIVEN the rollback timer is active, the prior owner is isolated, device 1 has no open owner, and exact metadata still matches
- WHEN the runbook changes invocation count from zero to one and directly invokes probe mode
- THEN the first status, mismatch, initialization failure, signal, or timeout terminates physical search
- AND no alternate target, direct runtime-binary command, interpreter fallback, or retry executes

#### Scenario: Exact constant masks pass
- GIVEN the sole repaired process reaches all exact comparisons
- WHEN evidence is classified
- THEN success requires fourteen unique `mismatches=0 PASS` records covering seven patterns at lengths 1 and 32
- AND the process returns zero with `constant-tile device probe: PASS`

#### Scenario: Terminal evidence restores and bounds claims
- GIVEN the sole repaired process returns any terminal result
- WHEN the runbook exits
- THEN ordinary restoration and independent rollback state are classified with service, endpoint, container, and board evidence
- AND no full-WKV, decode, performance, or general P150 compatibility claim is inferred

### Requirement: ttWKV7 exact probe-mode dispatch
r[onix.tenstorrent.native_runtime.ttwkv7.probe_mode_dispatch] After successful runtime-state validation, the composed ttWKV7 wrapper MUST execute its immutable probe runtime with `probe` as the first mode argument and MUST preserve every forwarded suffix argument exactly once and in order without creating a Tenstorrent device during package validation.

#### Scenario: Probe mode has no forwarded suffix
- GIVEN the production wrapper receives only `probe` and valid explicit runtime state
- WHEN a no-device dispatch target records its arguments
- THEN its complete argument vector is exactly one element equal to `probe`
- AND no Tenstorrent device is initialized

#### Scenario: Probe mode has a forwarded suffix
- GIVEN the production wrapper receives `probe` followed by a sentinel argument
- WHEN a no-device dispatch target records its arguments
- THEN its complete argument vector is exactly `probe` followed by the sentinel
- AND the mode is not dropped, duplicated, or reordered

#### Scenario: Production dispatch is inspected independently
- GIVEN the composed package's actual wrapper and immutable runtime executable
- WHEN package validation inspects production dispatch and runs the pinned no-device self-test
- THEN the probe branch contains the exact immutable target plus literal `probe` mode
- AND validation does not rely only on the fake target or caller-controlled `out`

### Requirement: ttWKV7 post-probe-mode-repair one-shot measurement
r[onix.tenstorrent.native_runtime.ttwkv7.constant_tile_measurement.probe_mode_repair] A fresh post-dispatch-repair measurement MUST bind the verified production argument vector, exact package and kernels, isolated device 1, explicit writable runtime state, independent timed restoration, exit-trap restoration, and zero invocation count before consuming exactly one probe process result without fallback or retry.

#### Scenario: Dispatch and restoration pass before isolation
- GIVEN a fresh package output, executable runbook, and zero invocation count
- WHEN device-free review completes
- THEN exact production dispatch, immutable paths, runtime state, runbook mode, owner control, root SSH, and rollback rehearsal all pass
- AND service-stop and rollback-arm counts remain zero

#### Scenario: One process exhausts the one-shot budget
- GIVEN rollback is active, the prior owner is isolated, device 1 has no open owner, and exact metadata still matches
- WHEN invocation count changes from zero to one and the runbook starts probe mode
- THEN the first status, mismatch, initialization failure, signal, or timeout terminates physical search
- AND no direct runtime-binary fallback, alternate command, or retry executes

#### Scenario: All exact masks pass
- GIVEN the sole process reaches all constant-tile comparisons
- WHEN evidence is classified
- THEN success requires fourteen unique `mismatches=0 PASS` records for seven patterns at lengths 1 and 32
- AND process status is zero with `constant-tile device probe: PASS`

#### Scenario: Terminal evidence restores and limits claims
- GIVEN the sole process returns any terminal result
- WHEN orchestration exits
- THEN service, endpoint, container, rollback, and board evidence classify restoration
- AND no full-WKV, decode, performance, or general P150 compatibility claim is inferred

### Requirement: ttWKV7 exact cross-kernel diagnostic
r[onix.tenstorrent.native_runtime.ttwkv7.cross_kernel_diagnostic] Onix MUST provide a device-free validated diagnostic boundary that accepts only reviewed writable Metalium runtime state and executes the immutable packaged ttWKV7 runtime from a fresh one-shot with exactly `test all 1 1` in one process without caller-controlled kernel, shape, tolerance, target, suffix, fallback, or retry.

#### Scenario: Exact diagnostic dispatch is validated without a device
- GIVEN a fake executable target and valid temporary cache, log, and loopback Inspector state
- WHEN package validation invokes diagnostic mode
- THEN the captured argument vector is exactly `test`, `all`, `1`, `1` once and in order
- AND package validation does not enumerate, open, reset, or communicate with a Tenstorrent device

#### Scenario: Diagnostic vector is changed
- GIVEN a candidate wrapper or composed package dispatch
- WHEN the target, mode, kernel selector, group count, sequence length, order, multiplicity, or suffix differs from the reviewed vector
- THEN deterministic validation fails before device access

#### Scenario: Runtime state is unsafe
- GIVEN missing or non-exact device-1 visibility, a missing, relative, Nix-store, non-directory, or unwritable cache or log path, or a non-loopback or invalid Inspector address
- WHEN validation or diagnostic mode is requested
- THEN the wrapper fails before target execution

#### Scenario: One physical comparison runs from a reviewed plan
- GIVEN a fresh committed executable one-shot, exact reviewed store paths, healthy owner, independent restoration, and zero counters
- WHEN the operator directly launches the one-shot without arguments and it invokes diagnostic mode
- THEN invocation count changes from zero to one immediately before one timeout-bounded outer wrapper process
- AND the process runs the reviewed chunked and decodeL cases without an alternate command or retry

#### Scenario: Cross-kernel evidence is classified
- GIVEN the sole process returns any status or emits partial or complete numerical records
- WHEN the result is classified
- THEN classification uses exact chunked, decodeL, aggregate-result, process-status, restoration, and board evidence
- AND matching failures do not identify a unique shared component
- AND no full-WKV correctness, decode correctness, performance, or general P150 compatibility claim is inferred

### Requirement: Exact ttWKV7 data-movement diagnostic

r[onix.tenstorrent.native_runtime.ttwkv7.data_movement_diagnostic] Onix MUST provide a device-free validated ttWKV7 diagnostic boundary that uses exact production readers and writer without WKV compute, compares deterministic bf16-tagged layouts exactly, fixes a later physical launch to device 1 and one immutable mode, and forbids caller-controlled suffixes, alternate commands, fallback, or retry.

#### Scenario: Pure layout oracles pass
- GIVEN deterministic tags for every reviewed input, state, output, and sentinel position
- WHEN device-free self-tests compare exact expected reader streams and writer matrices
- THEN all positive fixtures pass and row/column transpose, tile permutation, duplicate/drop, wrong-scatter, and sentinel-overwrite fixtures fail

#### Scenario: Production data paths are isolated from compute
- GIVEN the pinned chunked reader, decodeL reader, and writer kernels
- WHEN the diagnostic workloads are constructed
- THEN reader capture drains circular buffer 21 directly, writer scatter feeds circular buffer 16 directly, and no compute kernel is created

#### Scenario: Data-movement kernels are architecture checked
- GIVEN pinned Blackhole and Wormhole RISCV data-movement compiler configurations
- WHEN the offline architecture check runs
- THEN both minimal peer kernels compile for both architectures without enumerating or initializing a device

#### Scenario: Runtime state or dispatch is unsafe
- GIVEN missing or non-exact device-1 visibility, unsafe cache/log paths, a non-loopback Inspector address, an invalid mode, a suffix argument, a mutable target, or an altered dispatch vector
- WHEN the production wrapper is checked or invoked
- THEN it fails before target execution or device access

#### Scenario: One later physical comparison is complete
- GIVEN a committed one-shot fixed to exactly one device-1 data-movement process
- WHEN the immutable diagnostic executes
- THEN it records exactly one result for each reader/path and writer/path combination, one aggregate marker, raw status, invocation count one, and healthy independent owner restoration

#### Scenario: Physical output is incomplete or mismatched
- GIVEN a nonzero mismatch, missing or duplicate record, nonzero status, timeout, initialization failure, isolation failure, orchestration failure, or invalid reviewed runtime vector
- WHEN evidence is classified
- THEN the result is narrow and terminal for that one-shot and no retry, direct-runtime command, alternate probe, or broader compatibility claim is permitted

### Requirement: ttWKV7 high-information reader diagnostic loop

r[onix.tenstorrent.native_runtime.ttwkv7.reader_diagnostic_loop] Onix MUST validate every production-reader runtime vector and diagnostic control without a device, MUST independently distinguish CB21 capture and host upload packing from production reader behavior, and MUST preserve raw exact artifacts sufficient for offline classification after one reviewed one-shot process.

#### Scenario: Reader ABI vectors are validated without hardware
- GIVEN named decode, chunked-partial, and chunked-full reader cases with sentinel addresses
- WHEN the pure serializer emits each positional runtime vector
- THEN each vector matches an independently specified 18-field fixture
- AND the exhausted chunked `L=1/Lreal=1` vector plus mutations of chunk size, real length, chunk count, or instance bounds are rejected

#### Scenario: Capture and upload controls are independent
- GIVEN deterministic full-tile, input, and padded flat-state tags
- WHEN device-free oracles and architecture compilation validate the control workloads
- THEN CB21 loopback, all six input uploads, and complete state upload have exact expected layouts
- AND no production reader, writer, or compute kernel participates in those controls

#### Scenario: Reader cases cover tail and full chunks
- GIVEN the exact pinned decode and chunked production readers
- WHEN the future diagnostic case set is constructed
- THEN decode uses `L=1`, chunked partial uses `L=32/Lreal=1`, and chunked full uses `L=32/Lreal=32`
- AND every case fixes `nc=1` and instances `[0,32)`

#### Scenario: One process is observable offline
- GIVEN a downloaded control, reader, or writer buffer
- WHEN the imperative shell records evidence
- THEN it writes raw bf16 data and the exact serialized runtime vector under the reviewed log root before comparison
- AND deterministic records report mismatches by applicable region, tile, row, face, and head

#### Scenario: Controls or artifacts are incomplete
- GIVEN an invalid runtime vector, failed control, artifact-write error, missing or duplicate record, or incomplete output
- WHEN evidence is classified
- THEN production reader corruption is not inferred
- AND the result remains terminal for that one-shot without retry or broader compatibility claims

### Requirement: Exact one-process ttWKV7 reader diagnostic execution

r[onix.tenstorrent.native_runtime.ttwkv7.reader_diagnostic_execution] Onix MUST bind a fresh ttWKV7 reader diagnostic to one clean committed executable runbook, one immutable package and kernel closure, one exact device-1 wrapper command, zero-state counters, complete raw evidence, independent owner restoration, and a terminal no-retry classification.

#### Scenario: Preparation is safe and exact
- GIVEN the reviewed package, active system, owner helper, loopback trust fingerprint, run root, Inspector endpoint, and executable runbook
- WHEN offline preparation validates the boundary
- THEN wrapper target and vector, clean commit, metadata, writable isolated roots, free port, absent execution lock, and zero counters match exactly
- AND no Tenstorrent device is enumerated, initialized, opened, stopped, or contacted

#### Scenario: Exactly one physical process is consumed
- GIVEN an atomically acquired persistent execution lock, healthy owner state, armed independent rollback, successful isolation, and no device owner
- WHEN the invocation counter changes from zero to one
- THEN exactly one timeout-bounded production wrapper process runs with `TT_VISIBLE_DEVICES=1`
- AND no suffix, retry, fallback, alternate command, or direct-runtime invocation is permitted

#### Scenario: Evidence is complete
- GIVEN the sole process downloads any control, reader, or writer result
- WHEN evidence is persisted
- THEN each of thirteen reviewed names has raw bf16, producer arguments, consumer arguments, and one manifest result before interpretation
- AND the log contains thirteen unique case records and one aggregate marker

#### Scenario: Owner restoration is independent
- GIVEN owner isolation was attempted
- WHEN the diagnostic returns, times out, fails, or the shell receives a terminal signal
- THEN EXIT restoration and the independently armed root-systemd rollback protect owner recovery
- AND terminal evidence records service, container, HTTP health, board, rollback, and restoration status

#### Scenario: Result is classified without retry
- GIVEN complete or partial process, artifact, numerical, and restoration evidence
- WHEN the terminal decision table is applied
- THEN the result is one narrow reviewed classification with BLAKE3-hashed evidence
- AND no arithmetic, performance, broad P150 compatibility, or second-process claim is made

### Requirement: Architecture-aligned ttWKV7 reader gathers

r[onix.tenstorrent.native_runtime.ttwkv7.reader_gather_alignment] Onix MUST make every ttWKV7 production-reader DRAM face-row gather satisfy the pinned architecture's read alignment with NoC-addressable scratch ownership while preserving exact ABI, tile contents, CB cadence, and Wormhole behavior.

#### Scenario: Blackhole gathers a face row
- GIVEN a 32-byte face row at either residue within a pinned 64-byte Blackhole DRAM-read block
- WHEN a production reader gathers that row
- THEN it reads one 64-byte-aligned DRAM block into 64-byte-aligned bounded worker-L1 scratch derived from a reader-private circular-buffer page
- AND it does not use a process-local stack or private-LDM object as the NoC destination
- AND it copies exactly the selected 32 bytes to the requested destination row after the read barrier

#### Scenario: Wormhole gathers a face row
- GIVEN the pinned 32-byte Wormhole DRAM-read contract
- WHEN a production reader gathers that row
- THEN it retains one direct asynchronous 32-byte read to the exact destination
- AND it does not reserve the Blackhole scratch page
- AND the existing outer barrier, CB order, and push cadence remain unchanged

#### Scenario: Alignment planning is validated without hardware
- GIVEN source face-row offsets from both row parities and both column faces
- WHEN compile-time alignment plans are evaluated for pinned Blackhole and Wormhole
- THEN aligned source offsets satisfy the architecture boundary, selected intervals remain in bounds, and aligned offset plus remainder reconstructs every source offset
- AND a 64-byte-aligned scratch interval remains inside its reserved tile-sized page
- AND invalid direct Blackhole 32-byte gathers, stack-backed NoC destinations, and missing scratch reservation are rejected by static checks

#### Scenario: Scratch ownership is validated without hardware
- GIVEN the patched production readers, their host circular-buffer allocation, and a negative stack-scratch fixture
- WHEN the source gate runs
- THEN both readers derive Blackhole scratch from one reserved CB22 write pointer
- AND the host allocates at least one tile-sized CB22 page in decode and chunked modes
- AND no kernel producer or consumer aliases CB22
- AND the negative stack-scratch fixture is rejected

#### Scenario: Both readers remain architecture compilable
- GIVEN the patched chunked and decode readers plus all diagnostic data-movement peers
- WHEN the offline architecture gate runs
- THEN every source compiles as the correct RISCV processor for pinned Blackhole and Wormhole
- AND no device is enumerated, initialized, opened, stopped, or contacted

#### Scenario: Offline checks pass
- GIVEN exact ABI fixtures, layout controls, writer checks, package checks, and host configuration
- WHEN the patch is validated
- THEN all existing positive and negative checks pass without relaxed comparison or changed runtime vectors
- AND no physical correctness, new hardware authorization, or broad P150 compatibility claim is made

### Requirement: Plan-gated ttWKV7 hardware execution

r[onix.tenstorrent.native_runtime.ttwkv7.plan_gated_hardware_execution] Onix MUST permit a reviewed immutable ttWKV7 hardware runbook to execute without a prompt authorization sentence or authorization file while retaining exact device selection, immutable command dispatch, atomic attempt accounting, owner isolation, independent restoration, timeout, evidence completeness, and narrow result classification.

#### Scenario: Prompt-free runbook is ready
- GIVEN an immutable reviewed runbook with exact metadata, zero counters, an absent attempt lock, a healthy owner, and passing device-free checks
- WHEN the operator directly launches the runbook without arguments
- THEN no prompt authorization sentence, authorization file, environment toggle, or interactive confirmation is required
- AND the runbook still validates every immutable safety boundary before owner isolation or device access

#### Scenario: Prompt authorization gate is reintroduced
- GIVEN a candidate runbook or source checker that requires `authorization.txt`, an expected authorization sentence, or equivalent prompt-derived launch state
- WHEN device-free runbook validation executes
- THEN validation fails before publication
- AND no owner service or Tenstorrent device is contacted

#### Scenario: One-shot safeguards remain
- GIVEN the prompt-free runbook passes its immutable boundary checks
- WHEN it reaches the physical phase
- THEN it atomically consumes one attempt before one exact timeout-bounded wrapper process
- AND no caller suffix, alternate command, direct-runtime fallback, automatic retry, or broad compatibility claim is permitted

### Requirement: Exact one-process aligned-reader validation

r[onix.tenstorrent.native_runtime.ttwkv7.reader_alignment_validation] Onix MUST validate the corrected ttWKV7 Blackhole reader gathers with one fresh immutable device-1 process, complete controls and raw artifacts, independent owner restoration, and terminal no-retry classification.

#### Scenario: Corrected boundary is prepared
- GIVEN the committed package, kernel closure, executable runbook, strict trust, run root, free port, and zero counters
- WHEN preparation validates the boundary
- THEN exact paths, wrapper vector, absent attempt lock, and healthy owner match without a prompt authorization artifact
- AND no device is contacted during preparation

#### Scenario: Sole process compares the corrected readers
- GIVEN successful independent owner isolation and an atomically acquired attempt lock
- WHEN the atomic attempt and invocation counters change from zero to one
- THEN one timeout-bounded wrapper process runs CB21, six input, state, three reader, and two writer records
- AND every downloaded result preserves raw bf16 and both runtime vectors before comparison

#### Scenario: Corrected readers pass
- GIVEN thirteen complete unique records and process status zero
- WHEN every control, reader, and writer reports zero mismatches and the aggregate reports PASS
- THEN the result is `validated-aligned-reader-data-movement` for the exact reviewed boundary
- AND no WKV arithmetic, performance, or broad P150 claim is inferred

#### Scenario: Any result is terminal
- GIVEN a mismatch, missing artifact, invalid vector, nonzero status, infrastructure failure, or unhealthy restoration
- WHEN classification runs
- THEN the result is narrow, BLAKE3-hashed, and terminal
- AND no retry, fallback, suffix, alternate command, or direct-runtime invocation is permitted

### Requirement: Device-free RWKV lab session receipts
r[onix.tenstorrent.native_runtime.rwkv_lab.session_receipts] Onix MUST provide a device-free RWKV lab boundary that validates typed bounded-session manifests, derives deterministic BLAKE3 plan identifiers, and classifies saved evidence against exact attempt, process, timeout, owner-restoration, artifact, marker, and claim constraints without executing the planned command or accessing a Tenstorrent device.

#### Scenario: Valid manifest produces a deterministic plan receipt
- GIVEN a typed session manifest that binds exact immutable targets, one physical device, runtime state, a one-process budget, restoration policy, evidence expectations, and explicit non-claims
- WHEN the exported manifest is checked repeatedly
- THEN each check produces the same normalized plan and BLAKE3 plan identifier
- AND no command, owner-control operation, device selection, or Metalium initialization occurs

#### Scenario: Unsafe manifest fails before classification
- GIVEN a manifest with a relative or mutable target, mismatched device path, reusable process budget, insufficient rollback delay, duplicate expectation, missing claim boundary, or malformed runtime state
- WHEN the lab boundary validates the exported manifest
- THEN validation returns nonzero with a specific invariant diagnostic
- AND no evidence is promoted or command executed

#### Scenario: Complete success evidence is classified narrowly
- GIVEN saved evidence bound to the exact plan identifier with one process, one isolation, one restoration, zero terminal status, every required non-empty artifact, every exact success marker, healthy owner service, and healthy board
- WHEN evidence classification runs
- THEN the outcome is `passed` and the process budget is exhausted
- AND only the manifest's narrow success claim is emitted alongside every explicit non-claim

#### Scenario: Terminal evidence is incomplete
- GIVEN one terminal process result is bound to the exact plan but one or more required artifact roles are absent while owner and board restoration are healthy
- WHEN evidence classification runs
- THEN the outcome is `partial_diagnostic` and the process budget is exhausted
- AND no correctness success claim is emitted

#### Scenario: No process result is available
- GIVEN exact evidence records zero process attempts either before isolation or after safely restored isolation
- WHEN evidence classification runs
- THEN the outcome is respectively `not_run` or `blocked`
- AND the classifier does not synthesize a physical result

#### Scenario: Budget or restoration safety is violated
- GIVEN evidence exceeds the process budget, contradicts process ordering or timeout status, mismatches the plan identifier, or reports failed owner or board restoration
- WHEN evidence classification runs
- THEN the evidence is rejected or classified `unsafe` before ordinary success or failure
- AND no compatibility, correctness, or retry authorization is inferred

#### Scenario: Read-only CLI surface is inspected
- GIVEN the packaged `rwkv-lab` command and its source
- WHEN device-free package validation enumerates modes and execution primitives
- THEN only plan checking, plan-ID reporting, and saved-evidence classification are available
- AND no subprocess, owner isolation, device access, probe invocation, fallback, or retry path exists

### Requirement: Real-weight RWKV-7 layer reference
r[onix.tenstorrent.native_runtime.rwkv_lab.real_weight_layer] Onix MUST provide a device-free CPU reference that binds a pinned real RWKV-7 checkpoint, decodes its exact BF16 layer-zero schema, executes at least two fixed tokens through one complete layer with recurrent state carry, and emits deterministic BLAKE3-bound recurrence and layer receipts without invoking Metalium or a Tenstorrent device.

#### Scenario: Pinned checkpoint schema is accepted
- GIVEN the exact reviewed checkpoint revision with matching Nix SHA-256 and runtime BLAKE3 digests
- WHEN the harness decodes the required embedding rows and layer-zero tensors
- THEN every required tensor has the reviewed BF16 dtype, name, orientation, and shape
- AND no implicit transpose, missing tensor, duplicate tensor, or mutable model path is accepted

#### Scenario: Two real tokens exercise one complete layer
- GIVEN zero initial time-mix, channel-mix, and matrix state plus the checkpoint BOS and EOS embedding rows
- WHEN the harness executes layer zero sequentially in CPU FP32
- THEN the second token consumes the first token's carried state and produces finite recurrence vectors, final matrix state, and residual layer output
- AND layer normalization, time mixing, WKV7 recurrence, group normalization, gate correction, channel mixing, and both residual additions are included

#### Scenario: Recurrence orientation is cross-checked
- GIVEN the two-token real-weight recurrence inputs
- WHEN the production matrix update and separately structured scalar oracle evaluate the same state transitions
- THEN their state and output maximum absolute deviations remain within the named FP32 tolerance
- AND a transposed rank update, decay axis, outer product, or readout fails deterministic validation

#### Scenario: Deterministic receipt binds the integration rung
- GIVEN the exact checkpoint and fixed two-token layer execution
- WHEN the harness runs repeatedly
- THEN it emits identical BLAKE3 fingerprints and finite-value statistics for the recurrence inputs, final state, and final layer output
- AND the receipt records the checkpoint revision, content digests, dimensions, token IDs, arithmetic precision, and explicit non-claims

#### Scenario: Checkpoint or numerical evidence is invalid
- GIVEN a wrong digest, dtype, shape, tensor name, non-finite value, incomplete state carry, or recurrence-oracle mismatch
- WHEN device-free validation runs
- THEN the harness returns nonzero before publishing a passing receipt
- AND no fallback model, dynamic Python implementation, device process, or retry executes

#### Scenario: Layer evidence remains narrowly scoped
- GIVEN the real-weight layer receipt passes
- WHEN integration progress is reported
- THEN the claim is limited to the exact CPU FP32 two-token layer-zero execution and recurrence mapping
- AND no full-model logits, generated token, text generation, P150 parity, repaired-reader completion, performance, or general RWKV correctness is inferred

### Requirement: Real-weight RWKV-7 greedy token reference
r[onix.tenstorrent.native_runtime.rwkv_lab.greedy_token] Onix MUST provide a device-free CPU reference that binds the pinned real RWKV-7 checkpoint, executes the model-config BOS/EOS prefix `[1, 2]` through all twelve layers with independent carried state and reviewed cross-layer value mixing, applies the final model normalization and untied language-model head, and emits one deterministic greedy token receipt without invoking Metalium or a Tenstorrent device.

#### Scenario: Complete model schema is accepted
- GIVEN the exact reviewed checkpoint revision with matching Nix SHA-256 and runtime BLAKE3 digests
- WHEN the harness decodes all twelve layers, layer-indexed value LoRA tensors, final normalization, and language-model head
- THEN every required tensor has the reviewed BF16 dtype, name, orientation, and shape
- AND layer-zero-only tensors, later-layer-only tensors, the embedding table, and the untied head are not substituted for one another

#### Scenario: Fixed prefix carries independent state through every layer
- GIVEN zero initial attention, channel-mix, matrix, and oracle state for each of twelve layers
- WHEN model-config BOS/EOS IDs `1` and `2` execute sequentially through the complete model
- THEN every layer carries only its own first-token state into the second token
- AND state is neither reset between tokens nor shared between layers

#### Scenario: Token-local value anchor crosses layers
- GIVEN one prefix token entering layer zero
- WHEN its value projections pass through all twelve layers
- THEN layer zero establishes that token's `v_first`
- AND layers one through eleven interpolate their projected value toward the same token-local anchor using sigmoid of the reviewed value LoRA
- AND the anchor is recomputed at layer zero rather than reused across prefix tokens

#### Scenario: Recurrence and language-model head are cross-checked
- GIVEN finite all-layer hidden and recurrent values for the fixed prefix
- WHEN production recurrence, final normalization, production head projection, scalar recurrence oracles, and direct BF16-row head audit execute
- THEN every per-layer recurrence deviation remains within the named FP32 tolerance
- AND production and direct head paths agree on the greedy token and its logit within tolerance
- AND transposed recurrence or head orientation fails deterministic validation

#### Scenario: Deterministic receipt binds one greedy token
- GIVEN the exact checkpoint and fixed complete-model execution
- WHEN the harness runs repeatedly
- THEN it emits byte-identical BLAKE3 fingerprints and finite statistics for final hidden values, logits, and all recurrent states
- AND the receipt records the model-config prefix, generated token ID, top-two logits, greedy margin, per-layer deviations, checkpoint identity, dimensions, arithmetic precision, and explicit tokenizer/generation non-claims

#### Scenario: Complete-model evidence is invalid
- GIVEN a wrong digest, dtype, shape, tensor name, layer count, state owner, value anchor, value-LoRA activation, final norm placement, head orientation, non-finite value, recurrence mismatch, or head-audit disagreement
- WHEN device-free validation runs
- THEN the harness returns nonzero before publishing a passing token receipt
- AND no fallback model, dynamic Python implementation, device process, subprocess, or retry executes

#### Scenario: Greedy-token evidence remains narrowly scoped
- GIVEN the complete-model token receipt passes
- WHEN integration progress is reported
- THEN the claim is limited to the exact CPU FP32-from-BF16 checkpoint, model-config prefix, logits, and selected token ID
- AND model-config IDs `1` and `2` are not represented as tokenizer or generation-config BOS/EOS IDs
- AND no decoded text, generated-token recurrent step, sampling, multi-token generation, framework bit parity, P150 parity, repaired-reader completion, performance, or general RWKV correctness is inferred

### Requirement: Stateful RWKV-7 token-ID decode reference
r[onix.tenstorrent.native_runtime.rwkv_lab.stateful_decode] Onix MUST provide a device-free CPU reference that starts from zero state, executes model-config BOS seed ID `1`, selects exactly three greedy token IDs, feeds the first two selected IDs back through independently retained state for all twelve layers, and cross-checks every incremental step against zero-state replay without invoking Metalium or a Tenstorrent device.

#### Scenario: Generated tokens are executed with retained state
- GIVEN zero initial attention, channel-mix, matrix, and scalar-oracle state for each layer
- WHEN the fixed three-step decode executes from model-config BOS ID `1`
- THEN the seed selects the first token, the first selected token is the second recurrent input, and the second selected token is the third recurrent input
- AND no layer state is reset, omitted, or shared between those inputs

#### Scenario: Incremental execution matches zero-state replay
- GIVEN the exact processed input prefix at each decode step
- WHEN the incremental path retains prior state and the replay path recomputes that prefix from zero
- THEN final normalized hidden values, full logits, flattened recurrent matrices, top-two rankings, and direct BF16-row head audits agree within named tolerances
- AND every per-layer recurrence oracle remains within its named tolerance
- AND every post-seed retained-state hidden value differs from a same-token zero-state control by more than the named divergence floor

#### Scenario: Model-config stop policy is explicit and bounded
- GIVEN any selected token equals model-config EOS ID `2`
- WHEN the diagnostic has remaining steps
- THEN stop-ID observation is recorded and the exact three-step diagnostic continues
- AND the receipt states that model-config EOS ID `2` differs from ordinary byte EOS ID `261`, wrapper EOS ID `65,530`, and generation-config EOS ID `0`, so this is not normal generation-config stopping or text generation

#### Scenario: Stateful receipt is deterministic
- GIVEN the exact pinned checkpoint, model-config seed, step budget, and arithmetic policy
- WHEN the decode harness runs repeatedly
- THEN it emits byte-identical per-step token IDs, input chaining, top-two logits, margins, vector statistics, BLAKE3 fingerprints, replay deviations, retained/reset control deviations, and final state evidence
- AND the receipt records checkpoint identity, dimensions, exact budget, model-config stop policy, and explicit tokenizer/generation non-claims

#### Scenario: Stateful evidence is invalid
- GIVEN a wrong checkpoint schema or digest, incomplete layer inventory, state reset, shared state, stale generated-token input, changed token order, replay mismatch, non-finite value, head-audit disagreement, or shortened budget
- WHEN device-free validation runs
- THEN the harness returns nonzero before publishing a passing decode receipt
- AND no fallback model, dynamic Python implementation, subprocess, device process, or retry executes

#### Scenario: Stateful evidence remains narrowly scoped
- GIVEN the exact three-step fixed-ID receipt passes
- WHEN integration progress is reported
- THEN the claim is limited to the pinned CPU FP32-from-BF16 state transitions and selected IDs
- AND model-config seed ID `1` and stop ID `2` are not represented as tokenizer or generation-config BOS/EOS IDs
- AND no decoded text, tokenizer correctness, normal EOS behavior, sampling, arbitrary prompt support, long-context stability, framework parity, P150 parity, repaired-reader completion, or performance is inferred

### Requirement: Pinned RWKV-7 tokenizer and text reference
r[onix.tenstorrent.native_runtime.rwkv_lab.tokenizer_text] Onix MUST provide a device-free CPU reference that binds the pinned checkpoint's exact tokenizer, model, and generation-configuration artifacts, validates and implements its byte-level longest-prefix vocabulary, reports their conflicting BOS/EOS IDs, applies one fixed chat prompt with generation-config BOS ID `0`, performs bounded retained-state greedy generation with generation-config EOS ID `0`, and emits deterministic token, byte, text, state, and replay evidence without invoking Metalium or a Tenstorrent device.

#### Scenario: Exact tokenizer authority is accepted
- GIVEN the vocabulary, tokenizer configuration, added-token map, special-token map, tokenizer implementation, model configuration, and generation configuration at the exact accepted model revision
- WHEN the tokenizer harness loads those artifacts
- THEN every artifact matches its fixed Nix SHA-256 and runtime BLAKE3 identity
- AND the receipt distinguishes model-config BOS/EOS IDs `1/2`, tokenizer BOS ID `0`, ordinary byte-vocabulary EOS ID `261`, tokenizer-wrapper EOS added-special ID `65,530`, generation-config BOS/EOS IDs `0/0`, and byte vocabulary rows `1` through `65,529`

#### Scenario: Vocabulary and configuration are malformed
- GIVEN a wrong digest, missing or duplicate ID, duplicate token bytes, wrong declared byte length, malformed literal escape, noncontiguous row, changed special ID, changed model or generation ID, or tokenizer EOS text that does not encode to exactly ID `261`
- WHEN tokenizer validation runs
- THEN it returns an error before publishing a tokenizer or text receipt
- AND no fallback vocabulary, dynamic download, subprocess, or device path executes

#### Scenario: Byte tokenizer matches the pinned reference
- GIVEN fixed ASCII, multibyte Unicode, overlapping-token, control-byte, ordinary EOS, wrapper BOS/EOS, and chat-template fixtures
- WHEN the pure Rust tokenizer and pinned upstream reference encode and decode them
- THEN both select the same greedy longest-prefix token IDs and reconstruct the same exact bytes
- AND invalid IDs, invalid final UTF-8, and unsupported literal syntax fail deterministically

#### Scenario: Fixed chat prompt generates bounded text
- GIVEN zero initial state and the exact configured chat template applied to the fixed user message
- WHEN the argument-free text harness reproduces wrapper BOS ID `0` and wrapper EOS ID `65,530` in the rendered prompt and greedily generates within the named budget
- THEN each selected non-EOS ID is decoded to exact token bytes and fed back through independently retained state for all twelve layers
- AND generation stops immediately if generation-config EOS ID `0` is selected
- AND ordinary byte-vocabulary EOS ID `261` and wrapper EOS ID `65,530` are recorded but do not silently replace the generation stop policy

#### Scenario: Text execution matches zero-state replay
- GIVEN the complete prompt and generated-input prefix at each generation step
- WHEN the incremental path retains state and the replay path recomputes that prefix from zero
- THEN final hidden values, logits, recurrent matrices, top-two rankings, and direct BF16-row head audits agree within named tolerances
- AND post-prefix retained execution differs from a same-token zero-state control by more than the named divergence floor

#### Scenario: Tokenizer and text receipt is deterministic
- GIVEN the exact checkpoint, tokenizer artifacts, prompt, chat template, greedy policy, arithmetic policy, and generation budget
- WHEN the text harness runs repeatedly
- THEN it emits byte-identical prompt text and IDs, generated IDs, per-token bytes, decoded UTF-8 text, EOS reason, logits, margins, vector statistics, BLAKE3 fingerprints, replay deviations, and final state evidence
- AND the receipt records all model and tokenizer identities plus explicit non-claims

#### Scenario: Text evidence remains narrowly scoped
- GIVEN the fixed-prompt text receipt passes
- WHEN integration progress is reported
- THEN the claim is limited to exact CPU FP32-from-BF16 greedy execution and tokenizer behavior for the pinned artifacts and prompt
- AND no sampling, arbitrary prompt interface, long-context stability, framework numerical parity, P150 parity, ttWKV7 parity, repaired-reader completion, linguistic quality, or performance is inferred

### Requirement: Bounded caller-supplied RWKV-7 prompt reference
r[onix.tenstorrent.native_runtime.rwkv_lab.bounded_prompt] Onix MUST provide a device-free caller-supplied UTF-8 chat-message interface that requires explicit prompt-token and generated-token limits, enforces lower package hard caps before model execution, uses only the pinned Nix-store checkpoint and tokenizer authorities, and emits deterministic exact-token, byte, optional-text, state, and replay evidence without invoking Metalium or a Tenstorrent device.

#### Scenario: Valid bounded message executes
- GIVEN one UTF-8 user message, a positive prompt-token limit within the package cap, and a positive generated-token limit within the package cap
- WHEN the prompt harness applies the exact pinned chat template and wrapper tokenizer
- THEN the rendered prompt must fit both the caller prompt-token limit and package prompt-token cap without truncation
- AND retained-state greedy generation must execute for no more than the requested generated-token limit with generation-config EOS ID `0` stopping immediately

#### Scenario: Request shape or bound is invalid
- GIVEN a missing, duplicate, unknown, valueless, non-UTF-8, non-integer, zero, excessive, or actual-token-count-exceeding request input
- WHEN request parsing or validation runs
- THEN the harness returns nonzero before model execution and publishes no passing receipt
- AND it does not substitute defaults, truncate input, read caller-selected files, contact a network, spawn a subprocess, or access a device

#### Scenario: Exact generated bytes do not form complete UTF-8
- GIVEN bounded generated token bytes ending inside a UTF-8 scalar
- WHEN output decoding runs
- THEN the receipt preserves the exact bytes and records incomplete UTF-8 with absent decoded text
- AND it does not emit replacement characters or claim exact decoded text

#### Scenario: Caller prompt execution retains and replays state
- GIVEN the complete rendered prompt and each generated-input prefix
- WHEN incremental execution and zero-state replay run
- THEN complete final hidden values, recurrent matrices, top-two rankings, and direct BF16-row head audits agree within named tolerances
- AND retained execution differs from the same final input token executed from zero state by more than the named floor

#### Scenario: Caller prompt receipt is deterministic
- GIVEN the same pinned authorities, message, explicit limits, greedy policy, and arithmetic policy
- WHEN the harness runs repeatedly
- THEN it emits byte-identical request bounds, rendered prompt, prompt IDs, generated IDs, exact bytes, optional decoded text, stop reason, logits, margins, BLAKE3 fingerprints, replay deviations, and final state evidence
- AND the historical argument-free fixed-text receipt remains byte-identical to its accepted evidence

#### Scenario: Caller prompt evidence remains narrowly scoped
- GIVEN a bounded caller prompt receipt passes
- WHEN integration progress is reported
- THEN the claim is limited to exact CPU FP32-from-BF16 greedy execution and pinned tokenizer behavior within the reported bounds
- AND no sampling, secrecy, prompt safety, long-context stability, framework runtime parity, hardware parity, ttWKV7 parity, linguistic quality, or performance is inferred

### Requirement: Pinned CPU PyTorch RWKV-7 equation comparison
r[onix.tenstorrent.native_runtime.rwkv_lab.torch_equation_parity] Onix MUST provide a reproducible CPU PyTorch FP32-from-BF16 equation reference that binds exact Hugging Face, FLA v0.3.0, official RWKV, and checkpoint authorities and compares complete final-hidden, logits, and recurrent-state tensors for the model-config prefix `[1, 2]` against the Rust reference without invoking a GPU, Metalium, or a Tenstorrent device.

#### Scenario: Pinned source authorities are accepted
- GIVEN the exact checkpoint delegator, FLA v0.3.0 RWKV7 layer source, official RWKV equation source revision, and checkpoint
- WHEN the Nix comparison derivation materializes its inputs
- THEN every remote artifact matches its fixed Nix SHA-256 identity and recorded runtime BLAKE3 identity
- AND no mutable branch, dynamic package install, or runtime download is accepted

#### Scenario: Complete CPU equation comparison passes
- GIVEN the accepted model-config prefix `[1, 2]`, zero initial state, exact BF16 weights decoded to FP32, and separately structured Rust and PyTorch implementations
- WHEN both execute all twelve layers, final normalization, and the untied language-model head
- THEN every final-hidden, logit, and flattened recurrent-state element is finite and its maximum absolute deviation remains within a named tolerance
- AND top-two token IDs agree exactly under the lowest-ID tie rule

#### Scenario: Framework comparison input is invalid
- GIVEN a missing field, wrong prefix, wrong vector length, non-finite element, changed value beyond tolerance, changed source identity, transposed tensor, or top-two disagreement
- WHEN comparison validation runs
- THEN it returns nonzero and publishes no passing parity receipt
- AND no fallback implementation, tolerance widening, GPU path, device process, or retry executes

#### Scenario: Equation comparison is deterministic
- GIVEN the same pinned authorities, CPU framework version, arithmetic policy, prefix, and comparison tolerances
- WHEN the comparison runs repeatedly
- THEN it emits byte-identical authority identities, vector lengths, top-two IDs, maximum deviations, tolerance decisions, and BLAKE3-bound receipt evidence

#### Scenario: Equation comparison remains narrowly scoped
- GIVEN the PyTorch equation comparison passes
- WHEN integration progress is reported
- THEN the claim is limited to the pinned complete-tensor CPU equation comparison for prefix `[1, 2]`
- AND no FLA kernel/runtime parity, Transformers generation parity, official checkpoint-runtime parity, general RWKV correctness, P150 parity, ttWKV7 parity, repaired-reader completion, or performance is inferred

### Requirement: ttWKV7 pinned-checkpoint host shape
r[onix.tenstorrent.native_runtime.ttwkv7.checkpoint_shape] The packaged ttWKV7 host MUST derive padded input storage and work dispatch for the pinned checkpoint's 64-wide, 12-head WKV shape with ceiling tile and group counts, MUST reject invalid shape requests before device creation, and MUST provide a deterministic argument-free device-free shape self-test while preserving the historical 64-wide, 32-head diagnostic default.

#### Scenario: Checkpoint shape self-test passes without a device
- GIVEN the reviewed checkpoint shape `S=64`, `H=12`, one sequence, one token, 32-row tiles, and two-instance chunked groups
- WHEN the argument-free shape self-test runs
- THEN host input preparation uses one padded head-tile row containing 12 exact real rows followed by 20 exact zero rows
- AND it reports two head-dimension tiles, one head-tile row, 768 channels, and six chunked work units without creating a Metalium device

#### Scenario: Odd instance count retains the final instance
- GIVEN a valid host shape whose sequence and head counts produce an odd recurrent-instance count
- WHEN chunked work units are derived
- THEN ceiling division assigns a final partial two-instance group
- AND no real head is omitted or replaced by a padded storage row

#### Scenario: Explicit checkpoint shape reaches launch preparation
- GIVEN mode `test` or `bench`, valid kernel and workload arguments, and explicit suffix `64 12`
- WHEN the host validates arguments and prepares native input storage
- THEN head-tile rows and buffer sizes derive from a 32-row padded head dimension
- AND recurrent work count derives only from the 12 real heads

#### Scenario: Shape request is invalid
- GIVEN a missing shape partner, malformed decimal, sign, zero, unsupported head size, overflow, unexpected suffix, or invalid workload count
- WHEN host argument and shape validation runs
- THEN the command returns nonzero with a specific diagnostic before device creation or allocation
- AND it does not coerce the value, fall back to defaults, retry, or invoke another command

#### Scenario: Historical diagnostic default remains stable
- GIVEN no explicit shape suffix and the fixed packaged diagnostic wrapper
- WHEN default host arguments and wrapper source are inspected
- THEN the host retains head size 64 and head count 32
- AND the diagnostic wrapper retains exactly `test all 1 1` with no caller-controlled suffix

#### Scenario: Host shape source regresses
- GIVEN installed patched host source with floor head-tile division, unpadded tilization, floor chunked grouping, or device creation before self-test return
- WHEN package source validation runs
- THEN publication fails deterministically
- AND no hardware result, numerical parity, repaired-reader completion, or compatibility claim is inferred

#### Scenario: Shape evidence remains narrowly scoped
- GIVEN the checkpoint-shape package and self-test pass
- WHEN integration progress is reported
- THEN the claim is limited to device-free host storage, indexing, validation, and dispatch preparation for `S=64`, `H=12`
- AND no ttWKV7 numerical parity, kernel execution, P150 correctness, serving behavior, performance, or new hardware authorization is inferred

### Requirement: Real-weight RWKV-to-ttWKV7 BF16 boundary fixture
r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_fixture] Onix MUST provide a deterministic device-free artifact that binds the pinned checkpoint's retained layer-zero second-token WKV inputs and pre-state to complete little-endian BF16 bytes in ttWKV7 host order, recomputes raw expected output and post-state from the BF16 boundary through independent CPU recurrence paths, and emits exact BLAKE3-bound evidence without invoking Metalium or a Tenstorrent device.

#### Scenario: Retained real-weight boundary is captured
- GIVEN the exact pinned checkpoint, zero initial state, and model-config prefix `[1,2]`
- WHEN layer zero processes the second token
- THEN the fixture captures the nonzero retained pre-state immediately before token ID `2`
- AND it captures complete `r`, `w`, `k`, `v`, `a`, and `b` vectors plus raw recurrence output and post-state before group normalization or output projection

#### Scenario: ttWKV7 BF16 artifacts are encoded
- GIVEN 12 heads, head size 64, hidden size 768, and a 49,152-element retained state
- WHEN the boundary encoder runs
- THEN it emits all six 768-element vectors in fixed host order `[a,w,k,v,r,b]`, one retained pre-state, one 768-element expected output, and one expected post-state
- AND every artifact contains complete lowercase hexadecimal little-endian BF16 bytes, exact element and byte counts, and a BLAKE3 identity

#### Scenario: BF16 expected recurrence passes
- GIVEN the encoded vectors and pre-state decoded exactly from their BF16 bit patterns into FP32
- WHEN separately structured matrix and scalar recurrence implementations execute
- THEN complete expected raw-output and post-state tensors agree within the named recurrence tolerance
- AND the encoded expected artifacts derive from the BF16-boundary matrix result rather than the unquantized checkpoint calculation

#### Scenario: Boundary input is malformed or changed
- GIVEN a missing tensor, wrong ABI order, wrong shape, wrong byte count, non-finite source value, odd hexadecimal length, changed BF16 byte, changed state orientation, or changed combined identity
- WHEN boundary validation runs
- THEN it returns nonzero and publishes no passing artifact
- AND it does not reorder tensors, substitute zero state, fall back to FP32 transport, widen tolerance, invoke ttWKV7, or retry

#### Scenario: Fixture is deterministic and package-owned
- GIVEN the same pinned checkpoint, prefix, layer, BF16 policy, ABI order, and recurrence policy
- WHEN the argument-free fixture runs repeatedly
- THEN it emits byte-identical complete JSON and ordered combined BLAKE3 identity
- AND the package-installed canonical fixture matches stdout exactly while every caller argument is rejected

#### Scenario: Historical references remain stable
- GIVEN the boundary capture refactors shared layer-zero execution
- WHEN package validation runs
- THEN all accepted layer, greedy-token, stateful-decode, fixed-text, bounded-prompt, and framework comparison evidence remains unchanged
- AND no historical claim is widened to BF16 full-layer or ttWKV7 parity

#### Scenario: Boundary evidence remains narrowly scoped
- GIVEN the real-weight BF16 boundary fixture passes
- WHEN integration progress is reported
- THEN the claim is limited to exact logical BF16 transport bytes and CPU FP32 recurrence expectations for layer zero's second token
- AND no ttWKV7 execution, Metalium parity, P150 correctness, repaired-reader completion, token generation, serving behavior, performance, or new hardware authorization is inferred

### Requirement: Real-weight RWKV-to-ttWKV7 host-layout validation
r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_host_layout] Onix MUST provide a deterministic device-free cross-package check that validates the exact pinned real-weight BF16 boundary through ttWKV7's production host input-padding, state-upload, tiled-NFACES, and writer output/state layouts without initializing a Metalium device.

#### Scenario: Production and validation share the host-layout core
- GIVEN the accepted 12-head checkpoint shape and ttWKV7 host path
- WHEN input padding, state upload, or writer indices are constructed
- THEN production and validation compile against the same pure deterministic host-layout core
- AND the core performs no filesystem, environment, process, network, clock, logging, or device operation

#### Scenario: Canonical fixture authorities are accepted
- GIVEN the package-installed real-weight boundary fixture
- WHEN boundary validation parses it
- THEN exact schema, model revision, target, dimensions, prefix, byte order, tensor order, logical shapes, counts, lowercase hexadecimal bytes, per-artifact BLAKE3, whole-file BLAKE3, and ordered BLAKE3 authorities pass
- AND every BF16 value is decoded from its explicit little-endian bit pattern without substitution or widening the transport format

#### Scenario: Real input and state uploads match Metalium layout
- GIVEN six `[12,64]` input vectors and retained `[12,64,64]` pre-state
- WHEN the shared host core pads inputs and sequence state and Metalium's CPU layout converter tilizes them
- THEN all real values and BF16 bits are preserved, all padded values are exact zero, and complete tiled buffers match an independent four-face tiled-NFACES oracle element-for-element
- AND untilizing the buffers reconstructs the exact logical tensors and padding

#### Scenario: Writer output and state layout is bijective
- GIVEN the accepted expected output and expected post-state for one sequence and one token
- WHEN the shared writer indices construct the padded `[96,768]` host matrix
- THEN complete output and state values occupy the reviewed output and interleaved state regions exactly once
- AND inverse extraction reconstructs every logical element while all tail rows remain exact zero

#### Scenario: Transformed buffer receipt is deterministic
- GIVEN the same pinned fixture and installed Metalium CPU layout authority
- WHEN the no-device boundary self-test runs repeatedly
- THEN it emits byte-identical complete transformed-buffer BLAKE3 identities and one domain-separated combined layout identity
- AND the cross-package Nix check locks the exact receipt without adding the fixture or checkpoint to ttWKV7's runtime package closure

#### Scenario: Boundary fixture or command is malformed
- GIVEN malformed JSON, a non-file path, missing or duplicate artifact, wrong metadata, wrong ABI order, wrong shape, changed byte, stale hash, uppercase or odd hexadecimal, transposed state orientation, wrong element count, truncated data, duplicated data, missing path argument, or extra command suffix
- WHEN boundary validation runs
- THEN it returns nonzero before device creation and emits no passing receipt
- AND it does not reorder, truncate, retry, fetch, substitute zero state, accept another fixture, or fall back to a hardware mode

#### Scenario: Existing boundaries remain stable
- GIVEN the new cross-package check
- WHEN package validation runs
- THEN historical ttWKV7 shape, data-movement, reader-alignment, architecture, and RWKV fixture receipts continue to pass
- AND production reader, compute, and writer kernels remain unchanged

#### Scenario: Host-layout evidence remains narrowly scoped
- GIVEN the real-weight host-layout check passes
- WHEN integration progress is reported
- THEN the claim is limited to exact device-free host buffer construction and Metalium CPU tiled-layout conversion for the pinned boundary
- AND no ttWKV7 recurrence execution, kernel correctness, P150 correctness, repaired-reader completion, generation, serving, performance, or hardware authorization is inferred

### Requirement: Real-weight ttWKV7 decode-reader ABI validation
r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_decode_reader_abi] Onix MUST provide a deterministic device-free cross-package check that binds the exact accepted real-weight BF16 host buffers to ttWKV7's production decode runtime ABI and unchanged reader source-page/tiled-face mapping without initializing a Metalium device.

#### Scenario: Production and validation share the decode ABI core
- GIVEN the accepted 12-head decode shape and one contiguous logical instance range
- WHEN reader, compute, and writer runtime arguments are constructed
- THEN production and validation compile against the same pure fixed-array decode ABI core
- AND the core rejects invalid dimensions, products, addresses, or ranges without filesystem, environment, process, network, clock, logging, or device operations

#### Scenario: Exact real host buffers enter reader validation
- GIVEN the package-installed boundary fixture and accepted host-layout identities
- WHEN decode-reader validation runs
- THEN it accepts only the exact whole-file fixture authority and reconstructs all six accepted tiled input buffers and the accepted tiled retained-state buffer
- AND every transformed BF16 identity matches the accepted host-layout boundary before reader indexing is modeled

#### Scenario: Complete retained state is gathered for 12 heads
- GIVEN the exact tiled `[32,49152]` retained-state buffer and logical instance range `[0,12)`
- WHEN the source-locked decode reader model applies production's flat-strip page and tiled-face formulas
- THEN all 1,536 state source pages, both 16-element face reads per row, and all 49,152 meaningful BF16 state values are covered exactly once in reader CB tile order
- AND an independent logical `[head,row,column]` tiled oracle matches every gathered bit without using reader source-page formulas

#### Scenario: Complete input vectors are gathered for 12 heads
- GIVEN the six exact tiled `[32,64]` input buffers with 12 logical and 20 padded head rows
- WHEN the source-locked decode reader model selects source pages and head rows
- THEN exactly 144 input page/row selections and 288 individual face reads reconstruct all 4,608 meaningful BF16 values in `[head,input,dimension]` order
- AND padded heads are never selected and unspecified destination rows 1 through 31 are neither fabricated nor included in passing evidence

#### Scenario: Decode source and receipt authorities are deterministic
- GIVEN the unchanged installed production reader source and the same pinned fixture
- WHEN validation runs repeatedly
- THEN the exact reader source identity, runtime vectors, source-page/face trace, state payload, input payload, and domain-separated combined identity are byte-identical
- AND the cross-package Nix check locks the receipt without adding the fixture or checkpoint to ttWKV7's runtime closure

#### Scenario: ABI, gather, fixture, or command is malformed
- GIVEN an invalid dimension, product, address, instance range, runtime field, state stride, head row, face selection, tensor order, state orientation, payload length, fixture byte, fixture length, missing argument, or extra suffix
- WHEN decode-reader validation runs
- THEN it returns nonzero and emits no passing receipt
- AND it does not sample, reorder, truncate, retry, fetch, substitute zero state, accept another fixture, change production kernels, or fall back to a hardware mode

#### Scenario: Existing boundaries remain stable
- GIVEN the new decode-reader ABI check
- WHEN package validation runs
- THEN historical host-layout, checkpoint-shape, synthetic data-movement, reader-alignment, and architecture checks continue to pass
- AND production reader, compute, and writer kernel sources remain unchanged and compile for Blackhole and Wormhole

#### Scenario: Decode-reader evidence remains narrowly scoped
- GIVEN the real-weight decode-reader ABI check passes
- WHEN integration progress is reported
- THEN the claim is limited to exact host runtime-vector construction and source-level page/face mapping of meaningful reader payloads for the pinned boundary
- AND no BRISC, NoC, CB initialization, compute, writer, P150, generation, serving, performance, or hardware authorization claim is inferred

### Requirement: Hardware-ready real-weight ttWKV7 boundary harness
r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_device_harness] Onix MUST provide a deterministic, fail-closed, hardware-ready harness that binds the exact accepted real-weight BF16 boundary to one future production ttWKV7 DecodeL workload without performing or authorizing device execution during package validation.

#### Scenario: Exact fixture is prepared before device creation
- GIVEN the accepted 420,072-byte boundary fixture
- WHEN fixture self-test, preflight, or device mode parses it
- THEN the exact whole-file, ordered-artifact, shape, order, byte, and per-artifact authorities are validated before any device creation statement is reachable
- AND another fixture, malformed bytes, changed metadata, missing argument, or extra suffix returns nonzero without a passing receipt

#### Scenario: Fixture mode shares production execution
- GIVEN exact `[a,w,k,v,r,b]` vectors, retained pre-state, and `G=1`, `L=1`, `S=64`, `H=12`
- WHEN the prepared fixture device mode is inspected or eventually invoked
- THEN it uses production's shared host padding, state upload, decode ABI, core partition, circular buffers, reader, compute, writer, workload, and writer extraction path
- AND it does not duplicate the hardware setup in a standalone implementation or modify production kernel sources

#### Scenario: Future workload cardinality is exact
- GIVEN the fixture device mode reaches the production workload shell
- WHEN execution policy is applied
- THEN exactly one workload enqueue is allowed with no warmup, timing loop, retry, fallback, alternate kernel, caller-selected shape, or caller-selected threshold
- AND output storage is deterministically initialized before the workload

#### Scenario: Complete future evidence is preserved
- GIVEN a future authorized workload reaches readback
- WHEN writer results are processed
- THEN the complete raw writer BF16 matrix, all 768 extracted output values, and all 49,152 extracted post-state values are written as separate artifacts
- AND a deterministic manifest and receipt bind fixture, source, runtime-vector, byte-count, BLAKE3, exact-bit-mismatch, PCC, NMSE, maximum-absolute-error, threshold, and non-claim fields

#### Scenario: Numerical decision is fixed before hardware observation
- GIVEN complete finite future output and state evidence
- WHEN the pure comparator classifies it
- THEN passing requires output NMSE and state NMSE each to be less than the fixed `6e-2` ceiling inherited from the reviewed `L=1` production test
- AND failure, timeout, incomplete artifacts, non-finite values, threshold equality, or threshold excess cannot emit the bounded success claim

#### Scenario: Fixture-bearing package is isolated
- GIVEN the ordinary ttWKV7 package and the separate boundary-device harness package
- WHEN runtime closures are inspected
- THEN ordinary ttWKV7 contains no layer harness, checkpoint, safetensor, boundary fixture, or PyTorch path and retains its baseline closure cardinality and existing Metalium Python identity
- AND the separate package exposes one fixed wrapper vector and a valid typed `rwkv-lab` single-process plan naming physical device 1 and explicit restoration evidence

#### Scenario: No-device modes remain no-device
- GIVEN package self-test, runtime preflight, Nix checks, and Cairn validation
- WHEN they run without hardware authorization
- THEN they test exact parsing, host preparation, expected extraction, comparison, receipt construction, wrapper behavior, plan validity, replay, and malformed-input rejection without initializing Metalium, opening a command queue, changing device ownership, or creating an execution lock
- AND source checks reject any fallback from a no-device mode into the device branch

#### Scenario: Existing ttWKV7 boundaries remain stable
- GIVEN the prepared boundary harness
- WHEN package regression checks run
- THEN historical host-layout, decode-reader ABI, checkpoint-shape, synthetic data-movement, aligned-reader, and dual-architecture checks continue to pass
- AND the production reader, compute, and writer kernel identities remain unchanged

#### Scenario: Prepared status is reported narrowly
- GIVEN all device-free harness checks pass
- WHEN integration status is reported
- THEN the claim is limited to deterministic readiness of the exact fixture, production execution path, evidence schema, numerical decision, wrapper, and session plan
- AND no repaired-reader completion, BRISC, NoC, compute, writer, P150, full-layer, full-model, generation, serving, throughput, latency, or hardware authorization claim is inferred
