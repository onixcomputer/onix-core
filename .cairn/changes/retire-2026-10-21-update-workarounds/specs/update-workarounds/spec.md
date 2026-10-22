# Update Workarounds Specification Delta

## ADDED Requirements

### Requirement: Temporary update workarounds are retired

r[onix.update_workarounds.retired] The repository MUST track every temporary build workaround introduced by the 2026-10-21 flake update together with the condition that retires it, and MUST remove each workaround once its condition holds.

#### Scenario: An upstream fix lands

r[onix.update_workarounds.retired.upstream]
- GIVEN a tracked workaround whose retirement condition holds on the current inputs
- WHEN the affected closures are built without the workaround
- THEN the builds MUST succeed
- AND the workaround and its tracking task MUST be removed and closed together
