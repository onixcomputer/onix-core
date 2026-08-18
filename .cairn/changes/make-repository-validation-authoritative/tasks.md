## Phase 1: Deterministic validation graph

- [ ] [serial] Declare explicit maintained Python test roots and exclude Pi worktrees, build outputs, secrets, caches, and generated trees. r[onix.validation.python.discovery]
- [ ] [serial] Repair Buildbot's public test import/cassette setup and enable hermetic Nix package checks. r[onix.validation.python.packages]
- [ ] [serial] Replace the static-server lookalike VM service with the production Clan/NixOS module. r[onix.validation.modules.production]
- [ ] [serial] Define the maintained mypy source scope and fix its existing type errors. r[onix.validation.python.types]
- [ ] [serial] Wire root tests, package tests, type checks, and production-module checks into the flake validation graph. r[onix.validation.coverage]
- [ ] [serial] Document a non-mutating local command equivalent to the CI graph. r[onix.validation.coverage]

## Phase 2: Positive and negative evidence

- [ ] [serial] Prove root pytest collects each maintained test once with `.pi/worktrees` present. r[onix.validation.python.discovery]
- [ ] [serial] Add positive and negative Buildbot package cases and verify they run during Nix build. r[onix.validation.python.packages]
- [ ] [serial] Add static-server production-module assertions that fail on private/public policy regressions. r[onix.validation.modules.production]
- [ ] [serial] Add a negative mypy fixture or equivalent gate self-test proving maintained type errors fail the check. r[onix.validation.python.types]
- [ ] [serial] Run focused pytest, mypy, package, VM/evaluation, and flake checks. r[onix.validation.coverage]
- [ ] [serial] Run Cairn validation and proposal/design/tasks gates. r[onix.validation.coverage]
