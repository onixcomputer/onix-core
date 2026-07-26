## Phase 1: Source policy

- [x] [serial] Bind the reviewed RID, commit, source digest, and existing transport boundaries. r[onix.radicle_source_admission.policy]
- [x] [serial] Derive primary seed, HTTPS, and replica public-source lists from the exact three-source set. r[onix.radicle_source_admission.derivation]
- [x] [parallel] Add positive exact-set tests and negative missing, unknown, duplicate, malformed, and mismatch tests. r[onix.radicle_source_admission.validation]

## Phase 2: Runtime evidence

- [x] [serial] Stage the public source on both live seeds while preserving separately managed private policy. r[onix.radicle_source_admission.deployment]
- [x] [serial] Verify exact native and HTTPS acquisition, write rejection, source digest, and controlled single-seed behavior. r[onix.radicle_source_admission.probes]

## Phase 3: Acceptance

- [x] [serial] Bind producer governance evidence, emit typed BLAKE3 admission evidence, sync the accepted specification, and archive. r[onix.radicle_source_admission.evidence]
