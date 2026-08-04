# Radicle Forge Operations Specification

## Purpose

Define bounded onix-core acceptance of controlled native forge metadata observations without transferring source-host, review, CI, canonical-ref, deployment, or release authority.

## ADDED Requirements

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
