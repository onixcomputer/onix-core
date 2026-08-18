# Proposal: Remove the ttWKV7 prompt authorization gate

## Why

The ttWKV7 diagnostic runbooks already bind immutable package and kernel paths, one physical device, exact command vectors, atomic attempt locks, owner isolation, independent timed restoration, hard timeouts, complete evidence, and terminal classification. Requiring a separately supplied sentence in `authorization.txt` adds no device-safety property and serializes every reviewed hardware iteration on conversational state.

## What Changes

- Remove prompt-sentence and `authorization.txt` checks from live ttWKV7 hardware-run requirements and the prepared aligned-reader runbook.
- Make a reviewed immutable runbook directly launchable after its device-free gates and zero-state checks pass.
- Retain exact device selection, owner isolation, independent rollback, attempt accounting, timeout, no fallback or retry, evidence completeness, and narrow claims.
- Add positive and negative checker coverage that accepts the prompt-free runbook and rejects reintroduction of an authorization-file gate.

## Impact

- **Files**: the accepted Tenstorrent native-runtime specification, the active aligned-reader validation change, its runbook, and its source checker
- **Operations**: this change removes a launch prerequisite but does not itself invoke a hardware process
- **Safety**: immutable-plan, least-privilege owner-control, restoration, timeout, attempt-lock, and evidence requirements remain unchanged
- **Iteration**: reviewed hardware diagnostics no longer wait for an exact conversational phrase
