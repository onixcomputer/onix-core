# Radicle Forge Operations Specification

## Purpose

Defines the `radicle-forge-operations` capability.

## Requirements

### Requirement: Controlled fixture migration

r[onix.radicle_forge_ops.controlled_fixture] onix-core MUST retain the exact normalized controlled fixture, Valence plan, native built-in observations, and offline-verifiable binding for every accepted live fixture migration. Execution MUST use the planned importer signer, one explicitly selected repository, and built-in `xyz.radicle.issue` or `xyz.radicle.patch` refs only.

#### Scenario: Reviewed controlled batch is executed

- GIVEN a reviewed valid plan for one selected repository and the exact planned importer signer
- WHEN preview reports no writes and the operator explicitly executes the native import
- THEN built-in evaluator observations and an offline-verifiable binding MUST identify every source record and target object.

### Requirement: Live built-in observation

r[onix.radicle_forge_ops.live_observation] onix-core MUST verify accepted migrated objects through native evaluator observations and ordinary Radicle tooling, MUST preserve imported reviews as attribution-only comments, MUST require importer signed refs at feature level `parent`, and MUST verify selected seed and read-only transport convergence without changing canonical `main`.

#### Scenario: Objects converge without authority promotion

- GIVEN a solved imported issue and archived imported patch whose source review is attribution text
- WHEN ordinary Radicle tooling, Aspen, desktop, and HTTPS are observed
- THEN the issue, patch, Author refs, and `parent` sigrefs MUST agree while no imported approval or canonical mutation is claimed.

### Requirement: Idempotent exact-mapping replay

r[onix.radicle_forge_ops.idempotent_replay] an accepted existing mapping MUST bind the same source-record BLAKE3, target type, and target object, and native replay MUST reload the built-in object while changing zero refs.

#### Scenario: Existing mappings are replayed

- GIVEN exact mappings for all previously imported records
- WHEN planning, native execution, and binding are repeated
- THEN every decision MUST be `verify_existing`, the binding MUST verify offline, and the repository ref set MUST remain unchanged.

### Requirement: Forge migration boundaries

r[onix.radicle_forge_ops.boundaries] accepted onix-core evidence MUST identify controlled fixture scope and MUST NOT claim source export completeness, actor authenticity, source signature or timestamp preservation, semantic equivalence, approval equivalence, merge eligibility, CI correctness, canonical authority or mutation, durability, release readiness, or whole-stack GitHub independence.

#### Scenario: Fixture evidence remains bounded

- GIVEN a controlled fixture whose source-host API was not consulted
- WHEN the receipt and operational evidence are reviewed
- THEN fixture scope and all mandatory non-claims MUST remain explicit and no downstream authority MUST be inferred.

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
