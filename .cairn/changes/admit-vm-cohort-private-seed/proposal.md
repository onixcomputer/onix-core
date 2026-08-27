## Why

VM Cohort is published at private Radicle RID `rad:z2QJLUqyAZnnHPiZQ1BFjLsX9ush3`.

The local canonical ref is current, but the fleet reconciler removes repositories outside its exact private allowlist. Manual seeding therefore cannot provide durable replication.

## What Changes

- Admit the VM Cohort RID to the reviewed private Radicle source set.
- Mirror the exact RID through node checks, replica checks, and both settings validators.
- Keep the repository on native private Radicle only. Do not expose it through public HTTP or HTTPS routes.
- Reconcile the seed fleet and verify the stable VM Cohort evidence revision.

## Impact

- **Files**: service inventory, Radicle node and replica checks, settings validators, and Cairn lifecycle evidence.
- **Testing**: focused node, replica, inventory, and strict Cairn checks plus live seed observation.
