## Why

`omp` (oh-my-pi) is a terminal coding agent that runs its own multi-model
loop. The fleet already receives coding agents from the pinned
`llm-agents` flake input through the shared `llm-agents` Clan instance, but
that role grants the same CLI set to every `llm-client` host. `omp` is a
large self-contained build, and only two workstations run it.

## What Changes

- Add an `omp-agents` Clan instance that reuses the existing `llm-agents`
  module and scopes `omp` to `britton-desktop` and `aspen3`.
- Keep every other `llm-client` host on its current agent set.
- Add a focused repository check that covers the selected machines, an
  unselected machine, a bogus agent name, and the packaged agent's own smoke
  test.
- Deploy the two machines and confirm `omp` resolves on their PATH.

## Impact

- **Files**: `inventory/services/services.ncl`,
  `flake-outputs/_llm-agents-checks.nix`, `flake-outputs/checks.nix`.
- **Risk**: `omp` builds from source when the pinned revision is not in a
  substituter, so the first build is long. Nothing else in either machine's
  package list changes.
- **Non-goals**: no new flake input, no version pin outside `llm-agents`, no
  change to the shared `llm-agents` role, no change to agent configuration
  or credentials.
- **Testing**: contract validation of the service inventory, the focused
  positive and negative package-list check, and a build plus smoke test of
  the exact package the two machines install.

## Affected Specs

- `llm-agents-tools`: agent scope, package source, verification, and
  deployment.
