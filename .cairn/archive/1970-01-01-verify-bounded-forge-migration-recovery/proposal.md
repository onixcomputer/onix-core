# Change: Verify bounded forge migration recovery

## Why

The controlled Bounded Exec issue/patch migration is live and converged, but its retained receipt predates an encrypted post-migration checkpoint and clean-root recovery observation. onix-core must prove the exact migrated refs survive its existing off-site Borg boundary and remain stable through a bounded operational window without starting a duplicate restored node or granting canonical authority.

## What Changes

- Create an encrypted post-migration archive in the restricted desktop Borg repository and record complete BLAKE3 manifest facts. r[onix.radicle_forge_ops.recovery_checkpoint]
- Run the deployed clean-root byte verifier plus an isolated ordinary-Radicle semantic probe for the migrated built-in issue, archived patch, attribution-only review, and `parent` signed refs. r[onix.radicle_forge_ops.semantic_restore]
- Record an initial healthy probe and a delayed final probe separated by at least 24 hours. r[onix.radicle_forge_ops.observation_window]
- Keep canonical `main`, services, CI scope, identities, backup policy, and source repositories unchanged. r[onix.radicle_forge_ops.recovery_boundaries]

## Impact

- **Runtime:** One on-demand backup and read-only isolated restore probes; no restored node is started.
- **Evidence:** Adds typed recovery/observation evidence and redaction-safe raw outputs.
- **Authority:** No guard execution, canonical compare-and-swap, review promotion, deployment, or new credential path.
