# Tenstorrent Native Runtime Delta

## MODIFIED Requirements

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

## ADDED Requirements

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
