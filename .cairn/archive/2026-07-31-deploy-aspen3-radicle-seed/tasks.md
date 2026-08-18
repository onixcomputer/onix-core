## Phase 1: Generalize the replica boundary

- [x] [serial] Replace the fixed desktop validation facts with an exact reviewed replica-host matrix. r[onix.radicle_replica.configuration]
- [x] [parallel] Add positive and negative checks for both reviewed hosts, unknown hosts, mismatched facts, and reused identities. r[onix.radicle_replica.validation]

## Phase 2: Configure Aspen3

- [x] [serial] Add the bounded `aspen3` Radicle dataset and native-only service instance. r[onix.radicle_replica.deployment]
- [x] [serial] Generate and pin an `aspen3` machine identity that differs from the primary and desktop identities. r[onix.radicle_replica.identity_distinct]
- [x] [serial] Authorize the new seed DID in the non-secret private pilot identity and converge all three seed stores. r[onix.radicle_private_pilot.replication]

## Phase 3: Validate and deploy

- [x] [parallel] Run the focused replica check, the `aspen3` system build, and Cairn gates. r[onix.radicle_replica.validation]
- [x] [serial] Create the bounded dataset, deploy `aspen3`, reconcile policy, and inspect identity, listeners, monitoring, and authority boundaries. r[onix.radicle_replica.deployment]
- [x] [serial] Record redaction-safe evidence, update operations documentation, sync accepted specifications, and archive the completed change. r[onix.radicle_replica.evidence]
