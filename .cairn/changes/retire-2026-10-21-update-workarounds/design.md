# Design: Retire the 2026-10-21 update workarounds

## Context

Each workaround already sits next to a comment that explains its cause. The
causes live upstream (nixpkgs, llm-agents, onixpkgs, buildbot-nix,
`gcadapter-oc-kmod`), so each one ends on a different date.

## Decisions

### Decision: One open tracking change

**Choice:** Keep this change active with one task per workaround, and close
each task when its workaround is removed. Archive the change when every task
is closed.

**Rationale:** The list stays in one place that `cairn` already reports, and
each removal can land as its own small commit.

## Risks / Trade-offs

- A condition can hold without anyone noticing. Rechecking the list at the
  next flake update keeps the lag to one update cycle.
