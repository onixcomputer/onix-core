# Design: Plan-gated ttWKV7 hardware execution

## Goal and Success Evidence

Permit a reviewed immutable ttWKV7 hardware runbook to execute without reading an authorization sentence or file. Success requires the active aligned-reader runbook and accepted runtime specification to contain no prompt-authorization prerequisite while preserving exact package, kernel, device, owner, rollback, timeout, attempt-lock, command, artifact, and classification boundaries.

A hidden environment toggle, caller-selected command, broader sudo capability, removed restoration, reusable consumed runbook, automatic retry, direct-runtime fallback, or hardware execution during this policy change is false completion.

## Functional Core and Imperative Shell

The pure runbook checker validates source text and ordering. It requires immutable boundary markers, rejects forbidden prompt-authorization markers, and exercises positive and negative mutations without device access.

The runbook remains the imperative shell. It validates immutable metadata and zero state, atomically consumes its attempt lock, installs restoration traps, arms independent rollback, isolates the exact owner, proves device ownership is clear, invokes one exact timeout-bounded wrapper process, validates evidence completeness, and restores the owner.

## Decisions

### Prompt authorization is removed

A reviewed runbook MUST NOT require `authorization.txt`, an expected authorization sentence, or equivalent prompt-derived launch state. These artifacts do not strengthen the already immutable device and command boundary.

### One-shot safety remains

The change does not create an unrestricted lab shell. The prepared aligned-reader runbook still permits one attempt, one wrapper process, no caller suffix, no alternate command, no fallback, and no retry. Another process still requires a fresh reviewed runbook and zero-state boundary, but not a conversational authorization phrase.

### Negative coverage prevents regression

The source checker explicitly rejects an inserted authorization-file precondition. Existing negative fixtures continue to reject device changes, attempt-lock removal, counter removal, duplicate invocation, and evidence-validation removal.

## Risks and Mitigations

- Removing the prompt gate makes accidental direct launch possible. Exact executable identity, clean-tree metadata, zero counters, atomic attempt lock, owner-health checks, and no-argument CLI behavior remain mandatory.
- A failed process still consumes the one-shot budget. The persistent lock and counters remain authoritative.
- Service interruption remains possible during a run. Independent root-systemd rollback and EXIT restoration remain mandatory before isolation.
- This change does not claim numerical correctness or authorize arbitrary Tenstorrent commands.

## Validation

The pre-change runbook self-test, Bash syntax check, Cairn validation, and active-change proposal/design/tasks gates passed. After implementation, the prompt-free runbook self-test, authorization-gate negative fixture, Bash syntax, ShellCheck, Cairn validation, both changes' proposal/design/tasks gates, focused `ttwkv7` package and dual-architecture builds, targeted `nix fmt`, pre-commit tree formatting, and `git diff --check` pass without hardware access.

Repository-wide Cairn traceability remains at its pre-existing profile blocker: it discovers zero evidence files and therefore reports every accepted requirement missing, now 229 requirements. The new implementation and verification markers are present in source, but this global profile failure is not treated as evidence against the focused runbook checks.
