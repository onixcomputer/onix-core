# Seaglass Private Radicle and Kiln CI Specification Delta

## Purpose

Host Seaglass on the operator's private Radicle repository and make
`britton-desktop` its CI execution host, with Kiln as the first deployed
CI control plane consumer and the Radicle CI broker as the execution
boundary.

## ADDED Requirements

### Requirement: Exact revision available to the CI adapter

r[onix.radicle_ci.seaglass_acquire] `onix-core` MUST make the exact
pushed revision of the private Seaglass repository at RID
`rad:z3xXXCQXCTquvAawh41YYs8yC8xmk` available to the CI adapters from
the `britton-desktop` Radicle storage that the broker service uses,
without acquiring the repository from GitHub or a public Radicle seed.

#### Scenario: Exact revision is acquired from local storage

r[onix.radicle_ci.seaglass_acquire.accepted]
- GIVEN the private Seaglass RID is seeded with scope `all` into the
  Radicle storage used by the `britton-desktop` CI broker
- WHEN a push carries a new exact revision and the adapter resolves
  `git+file://$RAD_HOME/storage/$rid?rev=$oid` in the broker service
  environment
- THEN the adapter MUST build against that exact revision
- AND the acquisition MUST not depend on GitHub or a public Radicle seed

#### Scenario: Unseeded repository yields no run

r[onix.radicle_ci.seaglass_acquire.rejected]
- GIVEN a private repository is not present in the broker-watched
  Radicle storage or is outside the admitted private set
- WHEN the broker considers a trigger for that repository
- THEN the broker MUST not start a spurious run or expose repository
  contents beyond the admitted set

### Requirement: First deployed Kiln control-plane consumer

r[onix.radicle_ci.seaglass_kiln] `onix-core` MUST deploy the reviewed
Kiln package as the CI control plane for the Seaglass repository, and
MUST bind every broker run to one Kiln run identity and one exact
observed outcome.

#### Scenario: Binary trigger produces one bound Kiln result

r[onix.radicle_ci.seaglass_kiln.accepted]
- GIVEN a broker trigger for the admitted Seaglass RID carries the exact
  pushed revision
- WHEN the Kiln adapter processes the trigger line
- THEN it MUST emit a triggered response and exactly one terminal
  response for that run identity
- AND the terminal outcome MUST name the checked revision and the
  effective executor result

#### Scenario: Malformed trigger is rejected before effects

r[onix.radicle_ci.seaglass_kiln.rejected]
- GIVEN the trigger line is empty, oversized, non-JSON, unsupported
  protocol version, or carries an unknown field
- WHEN the Kiln adapter parses the trigger
- THEN it MUST fail without emitting a run line or starting an effect

### Requirement: Broker and Nix adapter execution on the desktop

r[onix.radicle_ci.seaglass_execute] `onix-core` MUST run the Seaglass
flake checks through the Radicle CI broker and the Nix adapter on
`britton-desktop`, with bounded execution and offline-consistent
behavior, and MUST record the result as a Radicle CI status.

#### Scenario: Seaglass checks run against the exact revision

r[onix.radicle_ci.seaglass_execute.accepted]
- GIVEN `britton-desktop` runs the broker with the Seaglass trigger
  filter and the Nix adapter for the private RID
- WHEN a push to the default branch of the private Seaglass repository
  is observed
- THEN the checked revision MUST build the admitted `checks.<system>`
  set
- AND the HTML report and Radicle CI status MUST record the terminal
  result without requiring GitHub

#### Scenario: Executor failure yields a failing status

r[onix.radicle_ci.seaglass_execute.rejected]
- GIVEN one admitted check fails, times out, or exceeds its output bound
- WHEN the Nix adapter completes the bounded job
- THEN the terminal result MUST be failure for that exact revision
- AND the failure MUST not be retried as an unknown outcome

### Requirement: Seaglass CI rail parity as flake checks

r[onix.radicle_ci.seaglass_checks] `seaglass` MUST express every CI rail
that currently runs in GitHub Actions and that is not already a flake
`checks.<system>` entry as a flake check, so the private CI path enforces
the same surface before GitHub Actions retires.

#### Scenario: Parity rail list is enforced

r[onix.radicle_ci.seaglass_checks.accepted]
- GIVEN the Seaglass flake advertises `checks.x86_64-linux` after this
  change
- WHEN the broker builds the admitted check set
- THEN the workspace nextest rail, generated-artifact drift gates,
  full-test-harness matrix metadata, browser E2E default rail, and steel
  runtime example rails MUST be present as named checks

#### Scenario: A GitHub-only rail is not enumerated

r[onix.radicle_ci.seaglass_checks.rejected]
- GIVEN a rail that runs only inside the GitHub Actions workflow
- WHEN the private CI path evaluates the Seaglass check set
- THEN the missing rail MUST appear in a named gap report

### Requirement: Independent private seed replication

r[onix.radicle_ci.seaglass_replication] `onix-core` MUST replicate the
private Seaglass repository on at least one seed outside the
`britton-desktop` personal node, and MUST record the observed seed set
in evidence with the exact reviewed revision.

#### Scenario: Replica holds the reviewed revision

r[onix.radicle_ci.seaglass_replication.accepted]
- GIVEN the private Seaglass RID is admitted to the secondary seed
- WHEN the replica store and the personal node are observed
- THEN both stores MUST hold the same exact reviewed revision and signed
  refs

#### Scenario: Single seed is presented as durable

r[onix.radicle_ci.seaglass_replication.non-claim]
- GIVEN only the personal node holds the private Seaglass repository
- WHEN availability evidence is collected
- THEN the receipt MUST NOT claim independent-seed durability until the
  secondary seed holds the reviewed revision
