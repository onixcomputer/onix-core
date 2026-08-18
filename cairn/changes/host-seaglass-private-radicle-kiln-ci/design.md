# Design: Seaglass private Radicle and Kiln CI on britton-desktop

## Host decision

The operator selected `britton-desktop` as the CI host. This machine
runs the personal Radicle node as user `brittonr`, is the reviewed backup
target for the production Radicle seed, and never suspends. It is inside
the accepted private-visibility seed set used by the existing private
pilot.

The alternative host, `tower`, is not managed by `onix-core`. Choosing
`britton-desktop` keeps the migration inside the reviewed `onix-core`
deployment boundary.

## Acquisition path

The broker adapter builds the exact pushed revision directly from the
Radicle storage the broker service uses. The adapter resolves
`git+file://$RAD_HOME/storage/$rid?rev=$oid`. No consumer flake input is
involved.

The deployment seeds the private Seaglass RID with scope `all` into
that `britton-desktop` Radicle storage. After seeding, acquisition never
needs GitHub or a public Radicle seed.

A private seed HTTP Git endpoint is intentionally out of scope. It is
useful only when a machine or flake consumes Seaglass as an input, which
this change does not do.

## Control plane and execution split

Kiln owns CI meaning: run identity, state transitions, terminal outcome
binding, and effect requests. Its Radicle broker adapter implements the
broker trigger protocol and returns one triggered line and one terminal
line per accepted run.

The Radicle CI broker owns event filtering and adapter dispatch. The Nix
adapter owns build execution for the admitted `checks.<system>` set over
the exact pushed revision.

The split is explicit. The control plane does not execute builds. The
executor does not own CI meaning.

## Why the broker and Nix adapter, not the pilot runner

The existing `radicle-ci-runner` module serves one fixed reviewed
commit with immutable lock identities and one bounded command. Seaglass
is a living repository with many rails and a large flake. The broker and
Nix adapter path handles arbitrary pushed revisions and builds the whole
admitted check set. It is the reference integration named in the Kiln
hosting and integration contracts.

## Seaglass flake parity

GitHub Actions currently runs rails that are not flake checks. The
private CI path builds only the flake `checks.<system>` set. Every rail
that must survive cutover becomes a named check. Any rail left
GitHub-only appears in a named gap report.

## Evidence

Each phase emits evidence under this change package: seed acquisition
probes, `git ls-remote` output, adapter fixtures, executor bound
records, the checked revision report, the seed-set observation, and the
final parity gap report. The change archives only after every gate
passes.
