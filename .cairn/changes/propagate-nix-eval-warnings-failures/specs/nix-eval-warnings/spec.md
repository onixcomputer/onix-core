# Nix Evaluation Warnings Specification Delta

## Purpose

Distinguish clean evaluation, warnings, and evaluator failure without reporting broken evaluation as success.

## ADDED Requirements

### Requirement: Evaluation outcome uses child status and parsed evidence

r[onix.nix_eval_warnings.exit_contract] `nix-eval-warnings` MUST classify its result from both parsed warning evidence and the `nix-eval-jobs` process outcome.

#### Scenario: Clean evaluation succeeds

r[onix.nix_eval_warnings.exit_contract.clean]
- GIVEN `nix-eval-jobs` exits successfully
- AND no warning records or malformed output are observed
- WHEN the command classifies the result
- THEN it exits with the documented success code
- AND reports that no evaluation warnings were found

#### Scenario: Warning abort is reported as warnings

r[onix.nix_eval_warnings.exit_contract.warning]
- GIVEN valid warning records are parsed
- AND `abort-on-warn` causes evaluation to stop
- WHEN the command classifies the result
- THEN it exits with the documented warnings code
- AND renders the parsed warning evidence

#### Scenario: Evaluator fails without warnings

r[onix.nix_eval_warnings.exit_contract.error]
- GIVEN `nix-eval-jobs` exits nonzero
- AND no valid warning record explains the stop
- WHEN the command classifies the result
- THEN it exits with the documented error code
- AND it MUST NOT print a clean-evaluation message

### Requirement: Malformed evaluator output fails closed

r[onix.nix_eval_warnings.malformed] `nix-eval-warnings` MUST treat malformed or incomplete terminal evaluator output as an error when clean completion cannot be established.

#### Scenario: Invalid JSON accompanies failure

r[onix.nix_eval_warnings.malformed.json]
- GIVEN the evaluator emits a malformed JSON result and exits nonzero
- WHEN output is parsed and classified
- THEN the command exits with the error code
- AND reports a bounded parse/evaluation diagnostic

### Requirement: Exit classification is package-tested

r[onix.nix_eval_warnings.validation] The Nix package MUST run positive and negative tests for clean, warning, invalid-flake, missing-tool, malformed-output, and unexplained-nonzero outcomes.

#### Scenario: Invalid flake cannot pass

r[onix.nix_eval_warnings.validation.invalid_flake]
- GIVEN a nonexistent or invalid flake reference
- WHEN the packaged command runs
- THEN it exits with the error code
- AND the package regression test fails if exit zero is returned
