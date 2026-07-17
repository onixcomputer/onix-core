## ADDED Requirements

### Requirement: One-shot real-weight ttWKV7 boundary session
r[onix.tenstorrent.native_runtime.rwkv_lab.ttwkv7_boundary_one_shot] Onix MUST provide an immutable, argument-free, single-process session runbook for the accepted real-weight ttWKV7 boundary harness, with fail-closed attempt accounting, owner isolation, independent rollback, restoration, complete evidence, and deterministic classification, without executing or authorizing the runbook during validation.

#### Scenario: Exact accepted authorities are bound
- GIVEN the accepted boundary package, ordinary ttWKV7 package, readiness receipt, plan ID, physical device 1, owner service, owner-control helper, and active system
- WHEN the runbook checker validates the source
- THEN each authority occurs exactly as reviewed and caller arguments or mutable fixture/threshold/kernel/device selection are rejected

#### Scenario: Single attempt is consumed atomically
- GIVEN zero process, isolation, rollback, and restoration counters and no execution lock
- WHEN a future operator invokes the argument-free runbook
- THEN the run root and execution lock are created atomically and exactly one terminal wrapper-process attempt is recorded
- AND no retry, loop, fallback, alternate executable, direct ordinary-runtime invocation, or second probe is reachable

#### Scenario: Owner isolation precedes the workload
- GIVEN the current owner is active and healthy
- WHEN the future session advances toward the probe
- THEN restoration traps are installed and independent rollback is armed before owner isolation
- AND service stop, container absence, device-owner absence, and board health are proven before exactly one wrapper `probe`

#### Scenario: Timeout and restoration are bounded
- GIVEN the future probe starts
- WHEN it completes, fails, receives a signal, or reaches 900 seconds
- THEN TERM plus 10-second kill grace bounds the process and the EXIT path attempts owner restoration exactly once
- AND the 1,200-second independent rollback remains armed unless explicit restoration, HTTP 200 health, and rollback disarm all succeed

#### Scenario: Complete boundary evidence is required
- GIVEN the future probe returns
- WHEN evidence completeness is evaluated
- THEN prepared metadata, complete 147,456-byte writer, 1,536-byte output, 98,304-byte post-state, manifest, receipt, exact one-workload field, finite passing comparison, and success marker are all required for bounded success
- AND missing, malformed, mismatched, non-finite, failed, or timed-out evidence cannot emit the success claim

#### Scenario: Session outcome is classified after recovery
- GIVEN process, artifact, marker, owner, health, and board evidence
- WHEN the runbook materializes `rwkv-lab` evidence after restoration
- THEN the evidence is bound to the accepted plan and classified deterministically as `passed`, `failed`, `partial_diagnostic`, `blocked`, or `unsafe`
- AND safety failures outrank ordinary process results

#### Scenario: Runbook mutations fail static validation
- GIVEN a changed package, plan, device, invocation count, lock, counter, trap, rollback, isolation, restoration, probe order, evidence check, direct runtime path, retry, or caller argument
- WHEN checker self-tests evaluate the mutation
- THEN every changed source is rejected without executing it

#### Scenario: Validation remains device-free
- GIVEN runbook source, checker, formatting, and Cairn gates
- WHEN validation runs
- THEN no run root, cache, log, execution lock, owner change, device file, command queue, kernel process, or hardware evidence path is created or accessed
- AND passing claims only immutable source readiness for a separately authorized future session
