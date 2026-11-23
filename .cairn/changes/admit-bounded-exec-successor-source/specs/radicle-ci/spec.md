# Successor CI delta

## MODIFIED Requirements

### Requirement: Typed CI deployment configuration r[onix.radicle_ci.configuration]

Onix Core MUST lower a typed configuration that fixes the host, admitted RID,
production seed, signed-reference feature, bot identity, job command, resource
limits, lock identities, artifact/status locations, and monitoring policy. The
admitted RID MUST be the Bounded Exec successor `rad:zG25DRmacxYQcXzZmLKj8tmgYbEG`
at reviewed commit `9e64b2f429c8f9035a06fe60ace3adbf331c5598`, bound to the
vendored OnixOS CI policy v2 BLAKE3
`ab4e2ae72b22c4c2704aca88852e4e5f036c2ca7501d257d11bec8827af2ebb3`. The canonical
guard MUST stay bound to the frozen pilot RID and MUST record the successor as
retired, with its reason and reinstatement condition, while the successor's
threshold is 1; successor `onix/ci/v1` status is evidence only.

#### Scenario: Exact successor policy is accepted

- **GIVEN** Aspen1, the successor RID, feature `parent`, bounded limits, the vendored policy v2, and one pinned production seed
- **WHEN** the CI deployment configuration is validated
- **THEN** deterministic bot, scanner, runner, publisher, and monitoring settings are produced
- **AND** the guard profile still names only the pilot RID and the retirement set names only the successor

#### Scenario: Expanded authority is rejected

- **GIVEN** a different RID, delegate identity, external listener, unbounded limit, credential-bearing job, shared-cache write, deployment effect, or production seed-policy mutation
- **WHEN** the configuration is validated
- **THEN** deployment is rejected before a service can start
