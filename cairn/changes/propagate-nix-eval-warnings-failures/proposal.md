## Why

`nix-eval-warnings` collects the `nix-eval-jobs` return code but discards it. If evaluation fails before producing a parsed warning record, the tool prints "No evaluation warnings found" and exits successfully, allowing broken or nonexistent flakes to pass a warning gate.

## What Changes

- Classify clean evaluation, warnings found, and evaluator/tool failure as distinct outcomes.
- Return the documented error exit code for nonzero evaluation without valid warning evidence.
- Treat malformed or incomplete evaluator output as an error rather than a clean result.
- Add deterministic parser and command-runner tests for every outcome.

## Impact

- **Files**: `pkgs/nix-eval-warnings/src/nix_eval_warnings/__init__.py`, package tests, and exit-code documentation.
- **Risk**: Callers that relied on false-success behavior will begin receiving an error exit code.
- **Non-goals**: Do not reinterpret genuine warnings as infrastructure failures merely because `abort-on-warn` stops evaluation.
- **Testing**: Cover clean evaluation, warning abort, invalid flake, missing executable, malformed output, and nonzero status with no warnings.
