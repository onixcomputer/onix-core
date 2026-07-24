## Context

The command streams combined stdout/stderr through a warning parser and returns both parsed warnings and the child status. `main` ignores the status. `abort-on-warn` complicates classification because a nonzero child status can represent an expected warning abort, while a missing flake or evaluator crash is an infrastructure error.

## Decisions

### 1. Separate parsing from outcome classification

**Choice:** Keep line parsing pure and add a pure classifier over parsed warnings, malformed-output evidence, and child exit status.

**Rationale:** The distinction can be tested with finite in-memory fixtures instead of spawning Nix for every case.

### 2. Preserve the three documented exit classes

**Choice:** Return success only for zero child status with no warnings. Return the warnings exit when valid warning records exist, including an `abort-on-warn` stop. Return the error exit for nonzero status without valid warnings, malformed terminal output, or process-launch failure.

**Rationale:** Warning-triggered abort is expected, but unexplained evaluator failure is not.

### 3. Emit diagnostics without false clean text

**Choice:** Error outcomes include bounded evaluator diagnostics on stderr and never print "No evaluation warnings found." JSON mode receives a structured error object or a documented nonzero no-output contract.

**Rationale:** Operator text must agree with the exit status.

### 4. Package the tests

**Choice:** Add positive and negative tests to the Python package and enable them in its Nix derivation.

**Rationale:** `doCheck = false` and absent fixtures currently leave the status contract unverified.

## Risks / Trade-offs

- Combined output from future `nix-eval-jobs` versions may require parser fixture updates.
- A warning plus an unrelated crash is conservatively reported as warning unless explicit fatal evidence is available; tests should define the precedence.
- JSON output compatibility must be documented before changing its shape.
