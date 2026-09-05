# Verification: Kiln source refresh stabilization

## Static and fixture verdict

**PASS.** Live deployment remains pending.

## Focused module check

`nix build .#checks.x86_64-linux.kiln-aspen-radicle-ci-module --no-link -L` passed.

The check now requires:

- current ACL inspection through `getfacl`;
- conditional directory ACL updates;
- conditional file ACL updates;
- the existing symlink, file-type, source-path, group, capability, and no-network boundaries.

The check rejects the old unconditional `find ... -exec setfacl` form.

## Generated command fixture

The evaluated production admission command was copied to a temporary fixture. Only its source root and group were replaced.

Positive results:

- a first run added missing directory access, directory default, and file access ACLs;
- a second run left directory and file change timestamps unchanged.

Negative result:

- a source tree containing a symbolic link failed with the expected admission diagnostic.

## Machine and lifecycle checks

- Complete `britton-desktop` system closure build: PASS.
- Nix formatting check for both changed Nix files: PASS.
- Proposal, design, and tasks gates: PASS.
- Repository Cairn validation: PASS.

## Pending live evidence

The following evidence is required before archive:

1. Build and deploy the reviewed `britton-desktop` closure.
2. Reset the failed refresh service and path.
3. Start one admission refresh and the path unit.
4. Verify the path remains active after the settling interval.
5. Replay the blocked Seaglass revision.
6. Verify exact revision visibility, terminal report publication, and an empty broker queue.

## Non-claims

- Static checks do not prove deployed service recovery.
- Fixture quiescence does not prove arbitrary filesystem or inotify behavior.
- Source visibility does not prove CI correctness or release eligibility.
