# Tasks

## Integration

- [x] [serial] I1 Record the fresh canonical, reviewed candidate, merge-base, and parent identities. r[onix.radicle_source_admission.concurrent_integration]
  - Evidence: `evidence/validation.md` records the exact two parents, merge base, and divergence counts.
- [x] [serial] I2 Merge the reviewed admission history without rewriting either parent. r[onix.radicle_source_admission.concurrent_integration]
  - Evidence: the pending merge uses canonical `main` as first parent and the reviewed admission tip as second parent.
- [x] [serial] I3 Reconcile the production policy as one exact ordered five-source union. r[onix.radicle_source_admission.policy]
  - Evidence: `evidence/validation.md` records the ordered union and CI non-expansion.
- [x] [parallel] V1 Add positive exact-union checks and negative missing-source checks for both concurrent admissions. r[onix.radicle_source_admission.validation]
  - Evidence: primary and replica checks cover exact admission, both missing-source cases, unknown additions, duplicates, and malformed values.

## Validation

- [x] [parallel] V2 Run Nickel formatting and evaluation, focused primary/replica/admission Nix checks, and source evidence checks. r[onix.radicle_source_admission.concurrent_integration]
  - Evidence: `evidence/validation.md` records four passing focused Nix checks, passing Nickel export, and the pre-existing package-identity blocker.
- [ ] [serial] V3 Run Cairn validation, gates, synchronization, and archive with explicit authority non-claims. r[onix.radicle_source_admission.concurrent_integration]
