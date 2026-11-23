# Bounded Exec successor source admission delta

## MODIFIED Requirements

### Requirement: Exact governed source policy

r[onix.radicle_source_admission.policy]

Production Radicle public-source policy MUST admit exactly Bounded Exec, `artifact-auth`, `execution-graph`, Choregraph, `durable-file-publication`, the koiTerminal fork, canonical Artifact and the Bounded Exec successor `rad:zG25DRmacxYQcXzZmLKj8tmgYbEG`, in that order. Each entry MUST bind its reviewed revision and publication evidence. The successor MUST bind reviewed commit `9e64b2f429c8f9035a06fe60ace3adbf331c5598`, one delegate and threshold 1 under the OnixOS `bounded-exec-successor-single-delegate-bootstrap` profile, and every receipt relying on it MUST name that profile. The frozen pilot RID MUST stay admitted and served read-only.

#### Scenario: Eight ordered public sources are admitted

- GIVEN complete source identities for all eight repositories
- WHEN production public-source policy is evaluated
- THEN the exact eight canonical public RIDs MUST be admitted in order, with the successor last.

#### Scenario: Missing, duplicate, malformed, private, or unknown source fails

- GIVEN a required RID is absent, including the successor or the frozen pilot, or an entry is duplicate, malformed, private, or unaccepted
- WHEN policy validation runs
- THEN validation MUST fail.
