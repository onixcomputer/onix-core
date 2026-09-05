# Proposal: Stabilize Kiln source refresh

## Summary

- Make the Kiln Aspen source-admission script update only missing ACL entries.
- Prevent a source-refresh run from continuously retriggering its own path unit.
- Add positive checks for idempotent ACL inspection and negative checks for unconditional ACL rewrites.
- Recover the deployed path unit from its start-limit failure and replay the blocked Seaglass revision.

## Motivation

A Seaglass Radicle push on 2026-09-04 triggered the managed Kiln route correctly. The provider then failed because its admitted source view did not expose the exact revision before the finite wait expired.

The source-refresh path had entered `unit-start-limit-hit`. Its service ran repeatedly because the admission script called `setfacl` on every directory and file. Those attribute writes changed paths watched by `PathModified`, which triggered the service again.

Increasing the start limit or provider wait would hide the loop. The source shell must become quiescent after required ACLs are present.

## Affected Domains

- `modules/kiln-aspen-radicle-ci/default.nix`
- `flake-outputs/_kiln-aspen-radicle-ci-checks.nix`
- `modules/kiln-aspen-radicle-ci/README.md`
- managed `britton-desktop` source-refresh service and path unit

## Success Criteria

1. **SC-01 — ACL admission is idempotent**
   - Existing required directory and file ACLs cause no `setfacl` call.
   - Missing ACLs are added without widening permissions.
2. **SC-02 — Static regression checks fail closed**
   - The module check requires `getfacl` inspection and conditional updates.
   - The module check rejects the prior unconditional `find ... -exec setfacl` form.
3. **SC-03 — Source refresh remains bounded**
   - A repository update may cause one settling refresh after new objects appear.
   - The path unit must remain active instead of reaching its start limit.
4. **SC-04 — Live source visibility recovers**
   - The failed units are reset after deployment.
   - The blocked Seaglass commit becomes visible to the provider.
   - A replay reaches a terminal report without source-readiness exhaustion.

## Expected Verification

- Focused Nix module check for `kiln-aspen-radicle-ci`.
- Repository Cairn validation and change gates.
- Positive script-shape checks for ACL inspection.
- Negative script-shape checks against unconditional ACL mutation.
- Post-deploy systemd state and journal evidence.
- Exact Seaglass replay evidence through the managed report service.

## Non-Goals

- Do not widen the Lattice source mount or Radicle authority.
- Do not disable the source-refresh path.
- Do not increase retry or start-limit budgets to mask the loop.
- Do not bypass the admitted source view.
- Do not claim that source visibility proves CI correctness or release eligibility.
