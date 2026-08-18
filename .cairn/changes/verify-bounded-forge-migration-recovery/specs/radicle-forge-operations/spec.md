# Radicle Forge Operations Specification Delta

## ADDED Requirements

### Requirement: Encrypted recovery checkpoint

r[onix.radicle_forge_ops.recovery_checkpoint] onix-core MUST create a post-migration encrypted archive outside the primary failure domain, MUST bind complete state and recovery-input manifests with BLAKE3, MUST preserve the pinned node key pair and fingerprint, and MUST remove plaintext staging after resuming only previously active services.

#### Scenario: Post-migration archive succeeds

- GIVEN migrated built-in COB refs on the primary seed and sufficient bounded off-site capacity
- WHEN the reviewed on-demand backup completes
- THEN the latest encrypted archive MUST contain complete manifests created after those refs converged, the backup unit MUST exit zero, services MUST resume, and plaintext staging MUST be absent.

### Requirement: Built-in semantic restore

r[onix.radicle_forge_ops.semantic_restore] onix-core MUST verify the latest archive in a clean root using complete manifests and MUST evaluate the restored migrated records through ordinary built-in Radicle issue/patch tooling without network announcement or a restored node start.

#### Scenario: Migrated COBs survive clean-root restore

- GIVEN a byte-exact clean-root restore of the post-migration archive
- WHEN the isolated profile reloads the planned issue and patch
- THEN the issue MUST be solved, the patch MUST be archived at the exact base/head, imported review data MUST remain attribution-only, importer signed refs MUST retain feature level `parent`, and all restore roots MUST be removed.

### Requirement: Minimum operational observation window

r[onix.radicle_forge_ops.observation_window] onix-core MUST accept the operational observation only when successful start and end probes are separated by at least 24 hours and agree on exact canonical, issue, patch, and signed-ref identities across the selected local, primary, replica, and public read-only surfaces.

#### Scenario: Observation window completes

- GIVEN an accepted recovery checkpoint and successful initial probe
- WHEN the delayed probe runs at least 24 hours later
- THEN selected services MUST be healthy, the CI outbox and restore roots MUST be empty, backup headroom MUST remain sufficient, and canonical `main` MUST remain unchanged.

### Requirement: Recovery claim boundaries

r[onix.radicle_forge_ops.recovery_boundaries] recovery evidence MUST NOT claim source-host completeness, actor authenticity, approval equivalence, canonical eligibility or mutation, arbitrary Radicle correctness, durability beyond the measured window, secure deletion, or release readiness.

#### Scenario: Recovery evidence is reviewed

- GIVEN successful archive, restore, and observation outputs
- WHEN the typed receipt is accepted
- THEN every mandatory non-claim MUST remain explicit and no restored node, guard execution, deployment, or authority transfer may be inferred.
