# Unseeded repository produces no broker run — negative fixture

Date: 2026-08-18

## Purpose

Close the rejected-acquisition scenario in
`r[onix.radicle_ci.seaglass_acquire.rejected]` with a deterministic,
repository-owned negative fixture. A broker run requires two conditions:
storage presence in the broker-watched Radicle home, and admission by the
deployed trigger. The fixture proves a repository outside the admitted
private set fails both conditions.

## Fixture

The `seaglass-kiln-ci-policy` check in
`flake-outputs/_seaglass-kiln-ci-checks.nix` now contains a named negative
case over the unseeded candidate set `rad:z3t9ykR1HfG9UkyKoQQg5ikkzrTxg`
(the private pilot RID).

At evaluation time the check asserts every unseeded candidate fails
trigger admission. At build time a shell fixture simulates the broker's
storage precondition:

- the replication writer is the only path into the broker-watched managed
  Radicle storage;
- the writer must contain exactly one `rad seed` invocation;
- copying any unseeded candidate into the storage writer fails the gate.

The gate also keeps the existing positive side: the Seaglass RID, reviewed
revision, identity revision, and authoring node must all appear in the
replication command.

## Result

`nix build .#checks.x86_64-linux.seaglass-kiln-ci-policy` passed with the
fixture present. The negative case fails closed if any future change
admits the pilot RID, seeds it into managed storage, or starts a second
seed invocation.

A mutation check ran the same greps against the deployed replication
command. The real command contains exactly one `rad seed` invocation and
does not mention the pilot RID (gate passes). A mutated copy that appends a
second `rad seed` for the pilot RID makes the negative gate trigger (gate
fails), proving the fixture discriminates instead of passing vacuously.

## Non-claims

The fixture proves the onix-core configuration cannot start or expose an
unseeded repository. It does not re-run the upstream broker binary, so it
does not prove the broker's own storage enumeration behavior. Live
deployment evidence already recorded by the broker database
(`cibtool run list`) contains runs only for the Seaglass RID, which is
consistent with and not a substitute for this policy fixture.
