# Design: Fix broker announce namespace

## Failure boundary

The deployed `radicle-ci-broker` 0.31.0 calls `node.announce` with an empty
namespaces list. The Radicle node computes the announcement set from that
list, finds it empty, and rejects the command with
`no refs were announced for rad:…`. Every job COB create/update therefore
logs a spurious `JobFailure`, and the broker's announce path can never
propagate status. The COB writes themselves succeed, and the
`kiln-aspen-ci-status-sync` unit covers propagation, but the broker log and
its run marking path stay broken until the namespace is declared.

## Chosen mechanism

1. Backport the upstream fix: pass the broker's own node id
   (`node.nid()`) as the announced namespace in `src/cob.rs`.
2. Ship it as a one-line patch applied through
   `services.radicle.ci.broker.package` overrides in the machine
   configuration, so the nixpkgs package stays the source of truth.
3. Assert in the machine evaluation checks that the package carries exactly
   the announce namespace patch, so a nixpkgs version bump that drops or
   renames it fails the check instead of silently regressing.

## Approach-family registry

| Family | Mechanism | State | Evidence / gap |
| --- | --- | --- | --- |
| Backport namespace patch | Machine package override with a one-line patch | validated | Live event `25514adf5` finished with no `JobFailure` |
| Upgrade radicle-ci-broker | Move to a release that contains the fix | blocked as stronger | No release with the fix was available at the pinned nixpkgs revision |
| Tolerate the error in a wrapper | Ignore failures in the sync unit | rejected | Hides the broken announce instead of repairing it |

## Adversarial audit

Verification SHALL reject a patch that changes CI semantics, touches the
status-sync unit, or removes the package patch assertion. The positive path
SHALL assert the patch presence in the machine evaluation and one live
event announcing without `JobFailure`. The negative path SHALL fail the
module check when the patch is absent.

## Claim boundary

This change proves only that the broker announces its own node namespace
and that the machine evaluation pins the patch. It does not prove remote CI
correctness, delivery to every peer, or release eligibility.
