# Design: Idempotent source ACL refresh

## Context

The production Kiln provider can read only a bind-mounted Seaglass repository view. A root one-shot grants the Lattice source group read access to repository directories and files.

A systemd path unit watches pack and branch-reference paths. The current admission script always calls `setfacl` across the full tree. ACL attribute changes therefore create new path events. Repeated one-shot runs eventually hit the systemd start limit.

## Decision

Inspect each ACL before mutation:

1. Read the current ACL with `getfacl`.
2. For a directory, require both the access group entry and default group entry.
3. For a file, require the access group entry.
4. Call `setfacl` only when a required entry is absent.
5. Keep the existing recursive file-type and symlink admission checks.

A refresh may receive one event for newly admitted objects. A second settling run must make no ACL writes and must quiesce.

## Rejected Alternatives

### Increase systemd start limits

This permits more loop iterations but does not remove the loop. It also delays failure and increases host work.

### Increase provider source-readiness time

This gives the broken path more time but cannot recover a failed path unit.

### Remove the path unit

This makes new Git objects unreadable to the least-authority provider unless an operator runs the service manually.

### Grant broader repository permissions

This weakens the source boundary and bypasses the reviewed group ACL contract.

## Architecture Boundary

- The admission shell owns filesystem observation and ACL effects.
- The source path unit owns bounded orchestration after repository changes.
- The provider continues to poll only the admitted read-only view.
- Kiln and Lattice receive no new authority.
- The change does not alter CI policy or terminal-result meaning.

## Validation Design

The Nix module check must require these positive properties:

- `getfacl` is present in the generated admission command;
- directory access and default ACL entries are checked;
- file access ACL entries are checked;
- `setfacl` remains available for missing entries.

The same check must reject these negative properties:

- unconditional `find ... -exec setfacl` mutation;
- network tools in the admission shell;
- removal of the watched source paths or least-authority service settings.

Live validation must reset and start the deployed path only after the fixed system closure is active. It must then observe a source-visible exact revision and a terminal Seaglass CI report.

## Failure Boundary

If deployment or service recovery requires unavailable root authority, keep the change active. Report the exact deployment command and do not claim live recovery.
