## Phase 1: Exit classification

- [ ] [serial] Extract a pure classifier over parsed warning evidence, malformed-output state, and child process status. r[onix.nix_eval_warnings.exit_contract]
- [ ] [serial] Return success only for a clean zero-status evaluation with no warnings. r[onix.nix_eval_warnings.exit_contract]
- [ ] [serial] Preserve the warnings exit for valid warning evidence when `abort-on-warn` stops evaluation. r[onix.nix_eval_warnings.exit_contract]
- [ ] [serial] Return the error exit for unexplained nonzero status, process launch failure, and malformed terminal output. r[onix.nix_eval_warnings.malformed]
- [ ] [serial] Align human and JSON diagnostics with the classified outcome. r[onix.nix_eval_warnings.exit_contract]

## Phase 2: Validation

- [ ] [serial] Add positive tests for clean evaluation and warning-triggered abort. r[onix.nix_eval_warnings.validation]
- [ ] [serial] Add negative tests for invalid flake, missing executable, malformed JSON, and nonzero status without warnings. r[onix.nix_eval_warnings.validation]
- [ ] [serial] Enable package checks and reproduce that a nonexistent flake exits with the error code. r[onix.nix_eval_warnings.validation]
- [ ] [serial] Run focused package checks plus Cairn validation and gates. r[onix.nix_eval_warnings.validation]
