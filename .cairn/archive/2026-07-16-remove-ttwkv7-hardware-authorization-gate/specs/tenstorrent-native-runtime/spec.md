# Delta: Tenstorrent native runtime

## ADDED Requirements

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
