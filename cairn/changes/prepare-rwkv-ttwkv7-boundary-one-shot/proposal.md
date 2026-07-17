## Why

The exact real-weight boundary device harness, fixed wrapper, one-process plan, and `not_run` receipt are accepted, but invoking the wrapper directly would bypass the reviewed owner-isolation, independent rollback, restoration-health, board-health, attempt-lock, and evidence-classification controls used by the prior terminal hardware session. Those controls must be rebound to the final package and plan before any new authorization can be considered.

## What Changes

- Add an immutable argument-free one-shot runbook pinned to the accepted boundary package, readiness receipt, plan ID, owner-control helper, physical device 1, active system, timeout, rollback, evidence roles, and success marker.
- Add a pure Rust static checker with positive and adversarial fixtures for exact invocation cardinality, lock ordering, owner isolation/restoration, rollback, evidence validation, classification, and prohibition of alternate device commands.
- Validate the runbook and checker without creating the run root, changing owner state, opening a Tenstorrent device, invoking the wrapper, or consuming an attempt.

## Impact

- **Files**: Cairn change/archive runbook, Rust checker, and lifecycle evidence only.
- **Testing**: checker positive/self-test cases, source hashes/modes, package/plan/readiness authority checks, formatting, and clean Cairn gates. No hardware process is executed.
