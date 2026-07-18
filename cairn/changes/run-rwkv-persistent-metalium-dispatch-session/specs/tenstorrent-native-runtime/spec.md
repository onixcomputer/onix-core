# Tenstorrent native runtime delta

## ADDED Requirements

### Requirement: Run one persistent physical ttWKV7 dispatch session

The repository SHALL provide one immutable, recoverable, single-attempt session that routes two consecutive model tokens through one persistent device-1 Metalium owner using the canonical ttWKV7 dispatch ABI. r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_persistent_metalium_dispatch]

#### Scenario: One device owner serves the exact bounded call sequence

- **GIVEN** the accepted physical token-two seed, canonical dispatch ABI, persistent CPU lifecycle, exact checkpoint, and one newly approved device-1 attempt
- **WHEN** the archived argument-free runbook consumes its sole execution lock
- **THEN** exactly one host command SHALL launch exactly one Metalium child, create exactly one MeshDevice, execute calls `0..23` in token/layer order `(2,0)..(2,11),(3,0)..(3,11)`, enqueue exactly one production DecodeL workload per call, and close without retry, reconnect, fallback, or extra call

#### Scenario: Physical responses derive later requests

- **GIVEN** a canonical request is pending for one model layer
- **WHEN** the Metalium child returns a canonical response
- **THEN** the host SHALL validate exact repeated authority and request BLAKE3 before consuming output/state, SHALL use that physical output to complete the host layer, and SHALL use each layer's exact physical third-token BF16 post-state as its fourth-token pre-state

#### Scenario: Numerical and model evidence fail closed

- **GIVEN** twenty-four physically returned raw outputs and post-states plus an independently ordered BF16 oracle
- **WHEN** any response is stale, duplicate, reordered, truncated, trailing, non-finite, shape-drifted, request-unbound, outside the predeclared numerical ceiling, or causes a token ranking mismatch
- **THEN** the session SHALL terminate without exposing unvalidated output as accepted state and SHALL classify without a physical success claim

#### Scenario: Device-free checks cannot consume approval

- **GIVEN** package, fixture, protocol, driver, runbook, checker, and readiness validation before execution
- **WHEN** self-tests, mutation fixtures, Nix checks, or Cairn gates run
- **THEN** they SHALL use only CPU/fake transports, SHALL NOT create the fresh runtime root, inspect a board, open a device, isolate the owner, execute a kernel, or consume the sole approved attempt

#### Scenario: Restoration remains part of success

- **GIVEN** any exit after owner isolation or rollback-arm attempt
- **WHEN** the runbook restores ownership and captures terminal evidence
- **THEN** a safe success SHALL require complete artifacts, numerical pass, clean protocol close, healthy board evidence, owner restoration, and the expected HTTP status within the fixed window; a missed window SHALL remain `unsafe` without later upgrade

#### Scenario: Historical hardware evidence remains immutable

- **GIVEN** terminal tasks `30` and `64` and roots `/var/tmp/rwkv-ttwkv7-boundary-device-1` and `/var/tmp/rwkv-ttwkv7-boundary-device-2`
- **WHEN** the new session is prepared or executed
- **THEN** it SHALL use a distinct task and root and SHALL NOT retry, reuse, rename, delete, overwrite, or reinterpret either historical session
