## ADDED Requirements

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
