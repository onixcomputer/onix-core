# Design

## Completion contract

Completion requires a closed typed policy, deterministic status/event/result identities, pure guard validation, live built-in patch/revision materialization from a selected local repository, exact bot/delegate identity checks, threshold delegate review and `parent` signed-ref quorum, current Git ancestry, preview-by-default behavior, and an atomic expected-old compare-and-swap available only behind `--execute`. Positive and negative tests, focused Nix checks, Cairn gates, and retained non-production evidence must pass.

False completion includes trusting caller-supplied `signature_verified` booleans, parsing the old prose-only status as authority, accepting reviews for another revision, counting duplicate or non-delegate approvals, checking ancestry without current-ref equality, using an unconditional ref write, running the guard in the CI bot/runner services, widening repository CI scope, mutating production during validation, or claiming protocol-level mandatory CI.

## Functional core

The pure core receives already-loaded values:

- a Nickel-authored guard policy binding RID, accepted CI policy BLAKE3, exact Valence implementation revision, non-delegate bot DID, sorted delegate DIDs, threshold, required check name, target ref, and signed-reference feature `parent`;
- the existing typed CI event and result;
- the machine-readable bot status payload;
- the Valence exact-revision admission receipt; and
- live facts materialized from the Radicle evaluator and Git repository.

It recomputes canonical BLAKE3 identities for the event, result, status, Valence receipt, and guard decision. Admission requires exact agreement across every patch ID, revision ID, candidate OID, job ID, artifact digest, policy digest, bot identity, delegate set, review threshold, `parent` signed-ref threshold, canonical predecessor, target ref, and disposition. The decision contains expected-old and candidate OIDs only; it performs no I/O.

## Imperative shell

`radicle-ci-runner guard` requires explicit policy, repository, event, result, and Valence receipt paths. It opens exactly one Radicle storage repository, loads the built-in `xyz.radicle.patch` object and exact revision through the verified evaluator, extracts only a strict marker plus one closed JSON status line authored by the configured bot, and reads exact-revision built-in reviews authored by configured delegates. It independently loads and cryptographically verifies each delegate's `refs/rad/sigrefs`, requires feature level `parent`, and requires a threshold intersection of approving delegates whose signed `refs/heads/main` names the candidate. It reads canonical `refs/heads/main`, verifies the candidate object and descendant relation, then calls the pure core.

Without `--execute`, the shell prints an admitted preview and performs no write. With `--execute`, it uses libgit2 `reference_matching` with the admitted expected-old OID. This fails atomically if another actor changes the ref between observation and write. The shell rereads the ref and emits an external execution receipt; it does not sign delegate refs or represent the update as a Radicle merge.

## Signed status format

The non-delegate CI bot publishes:

```text
<!-- onix-radicle-ci-status:v1 -->
{"schema":"onix.radicle-ci-status.v1",...}
```

The closed payload binds policy, RID, patch/revision, check name, job/object, disposition, artifact, canonical event/result BLAKE3 identities, and the status non-claim. The enclosing built-in comment entry is signed by the bot key; the guard accepts the payload only when the evaluator reports that exact bot author.

## Authority boundary

No deployed service gains production-storage access. The existing scanner, runner, and publisher hardening remains unchanged. Possession of the package or an admitted preview is not canonical authority; filesystem permissions and explicit operator invocation remain required. The mechanism does not prove CI correctness, source correctness, delegate intent beyond observed signed reviews, seed convergence, protocol enforcement, merge semantics, release readiness, or post-update replication.
