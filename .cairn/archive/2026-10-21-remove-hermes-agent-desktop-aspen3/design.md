# Design: Remove Hermes Agent Desktop from aspen3

## Context

`bedb0b74` recorded the deployed state: no `hermes-agent` flake input, no
`hm-aspen3-hermes` instance, no `hermes` profile name, and one shared
`llm-agents` package list that gives the `hermes-agent` CLI to every
`llm-client` host. The profile file, the check that requires Hermes Desktop
on `aspen3`, and the specifications that describe it were left behind.

## Decisions

### Decision: Delete the leftovers instead of restoring the feature

**Choice:** Delete the profile, the check, and both specifications'
requirements.

**Rationale:** The operator chose to drop Hermes Desktop. A profile that no
contract admits and a check that can only fail hide real check failures.

### Decision: Keep the llm-agents settings contract check

**Choice:** Keep `llm-agents-settings` and its fixture, drop their Hermes
requirement markers, and make the fixture's positive case use the shared list
(`pi`, `openspec`, `hermes-agent`).

**Rationale:** The check guards the Nickel contract for the `llm-agents`
`packages` setting, which every `llm-client` host still uses. Only its
requirement link belonged to Hermes Desktop.

## Risks / Trade-offs

- Restoring Hermes Desktop later needs a new change that re-adds the flake
  input, the profile, and its checks.
