## Why

The official Hermes Agent Desktop reached `aspen3` through
`install-hermes-agent-desktop-aspen3` (0c9f1eba). The tree deployed on
2026-10-21 had already dropped its flake input, Home Manager instance,
profile name, and `llm-agents` package split, and the operator chose to drop
Hermes Desktop for good rather than restore it. The profile file, the
`hermes-agent-desktop` check, and two Hermes Desktop specifications remain.
They describe software that no machine installs, and the check fails.

## What Changes

- Delete the unreferenced `inventory/home-profiles/brittonr/hermes` profile.
- Delete the `hermes-agent-desktop` check and the bindings only it used.
- Keep the `llm-agents-settings` contract check and its fixture without the
  Hermes requirement markers, and align the fixture's positive case with the
  shared `llm-client` package list.
- Remove the requirements of `install-hermes-agent-desktop-aspen3` and of the
  older `add-hermes-desktop-aspen3`, whose community package 0c9f1eba had
  already replaced.

## Impact

- **Files**: `inventory/home-profiles/brittonr/hermes/default.nix`,
  `flake-outputs/_home-manager-checks.nix`, `flake-outputs/_module-checks.nix`,
  `inventory/services/fixtures/llm-agents-validation.ncl`, `.cairn/specs/`.
- **Risk**: no evaluated machine configuration changes. `aspen3` keeps the
  `hermes-agent` CLI from the shared `llm-agents` list.
- **Non-goals**: no change to the `hermes-gateway` Matrix module on
  `britton-desktop` or to the `llm-agents` package list.
- **Testing**: the home-manager and module checks, unchanged toplevels for
  the deployed machines, and `cairn validate`.

## Affected Specs

- `install-hermes-agent-desktop-aspen3`: every requirement is removed.
- `add-hermes-desktop-aspen3`: every requirement is removed.
