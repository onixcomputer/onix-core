## Why

The private Aspen canary passed its bounded live drills, but it does not receive broker traffic and its workflow is not a real CI build. The Kiln input promotion also changed the adapter CLI while the existing Seaglass broker retained the old command shape. Onix must first restore that route, then deploy the durable production host in parallel and cut over with an explicit rollback.

## What Changes

- Pin the legacy direct executor separately so the existing broker remains operational during staging.
- Deploy a distinct production Kiln Aspen host and Lattice workflow with immutable upstream revisions.
- Grant the workflow read access only to the exact Seaglass repository view and write access only to its report root.
- Replace the broker adapter command with an explicit `--protocol defelo --runtime aspen` composition after shadow gates pass.
- Retain an operator-selected legacy rollback with no automatic fallback.
- Prove live Radicle event handling, restart replay, uncertainty, failure, load, backup/restore, observability, and rollback before archive.

## Impact

- **Files**: flake inputs and lock, machine CI composition, Kiln Aspen modules and profiles, inventory, focused Nix checks, operator documentation, and Cairn evidence.
- **Testing**: legacy continuity, typed Nickel profiles, Nix module checks, full machine evaluation, managed deployment, real broker events, negative and recovery drills, and strict Cairn validation.
