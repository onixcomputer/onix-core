## Phase 1: Governed policy

- [x] [serial] Bind the reviewed RID, commit, source digest, producer identity, signed refs, threshold, and Cairn archive receipt. r[onix.radicle_source_admission.policy]
- [x] [serial] Derive Aspen1 native seeding, Aspen1 HTTPS, and desktop native seeding from the exact four-source public list. r[onix.radicle_source_admission.derivation]
- [x] [parallel] Add positive exact-set validation and negative missing, duplicate, malformed, serving-role mismatch, CI-widening, governance, and non-claim cases. r[onix.radicle_source_admission.validation]

## Phase 2: Managed deployment

- [x] [serial] Build the selected Aspen1 and britton-desktop system closures with the durable source in store-backed policy. r[onix.radicle_source_admission.deployment]
- [x] [serial] Deploy both closures without runtime-only overrides and preserve the separate private policy. r[onix.radicle_source_admission.deployment]
- [x] [parallel] Verify the reviewed commit and source digest through Aspen native transport, desktop native transport, and Aspen HTTPS. r[onix.radicle_source_admission.probes]
- [x] [parallel] Verify undeclared RID, receive-pack, wrong-service, missing-object, and seed-authority probes fail closed. r[onix.radicle_source_admission.probes]

## Phase 3: Acceptance

- [x] [serial] Emit typed Nickel and deterministic JSON/BLAKE3 admission evidence with explicit non-claims. r[onix.radicle_source_admission.evidence]
- [x] [serial] Run focused Nickel, Nix, Cairn, traceability, and repository validation. r[onix.radicle_source_admission.validation]
- [x] [serial] Synchronize the accepted specification and archive the completed change only after deployment evidence passes. r[onix.radicle_source_admission.evidence]
