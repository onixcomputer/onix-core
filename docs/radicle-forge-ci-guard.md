# Radicle forge CI canonical guard

r[verify onix.radicle_ci.canonical_guard.status]
r[verify onix.radicle_ci.canonical_guard.core]
r[verify onix.radicle_ci.canonical_guard.shell]
r[verify onix.radicle_ci.canonical_guard.authority]

The guard is an explicit onix-core operator capability for the Bounded Exec pilot. It is not a deployed reconciler and it is not available to the CI bot, credentialless runner, seed services, or Valence through their service permissions.

## Inputs

The command requires five reviewed typed inputs and one selected repository:

- `modules/radicle-forge-guard/generated/profile.json` — Nickel-authored exact RID/policy/Valence revision/bot/delegate/threshold/check/ref boundary;
- the original admitted `onix.radicle-ci-event.v1` file;
- the matching `onix.radicle-ci-result.v1` file;
- a Valence `valence.radicle-forge-operations.ci-admission.v1` receipt;
- the bare Radicle storage repository for the same RID; and
- an existing output capability root with a new relative output file name.

The Valence receipt is necessary but not authoritative. The guard recomputes its BLAKE3, reloads the built-in patch/revision evaluator, extracts the configured bot's signed machine status, reads exact-revision built-in delegate reviews, cryptographically verifies a threshold intersection of delegate `refs/rad/sigrefs` at feature level `parent` whose signed `refs/heads/main` names the candidate, rereads canonical `refs/heads/main`, verifies candidate presence and ancestry, and requires all facts to agree.

## Preview

```text
radicle-ci-runner guard \
  --repository /var/lib/radicle/storage/z2CpqLFpdP36fZXYUK5ZNWxMibpCo \
  --policy modules/radicle-forge-guard/generated/profile.json \
  --event event.json \
  --result result.json \
  --receipt valence-admission.json \
  --output-root evidence/radicle \
  --output guard-preview.json
```

Preview is the default. It writes a create-new external receipt and does not update a ref, COB, signed ref, policy, source file, or lifecycle file.

## Execute

After independently reviewing the preview and confirming the operator has the intended repository capability, repeat the same command with `--execute` and a new output file:

```text
radicle-ci-runner guard ... --output guard-execution.json --execute
```

Execution uses libgit2 `reference_matching` against the admitted expected-old OID. If the canonical ref changes after observation, the operation fails with no overwrite. On success the shell rereads the ref and records the observed candidate in the external receipt.

The command does not write delegate namespace refs or `refs/rad/sigrefs`, publish a Radicle merge operation, synchronize seeds, deploy systems, or release artifacts. Separate delegate signing, distribution, recovery, and lifecycle acceptance remain required when policy calls for them.

## Signed status

The publisher writes the status to the exact patch revision:

```text
onix-radicle-ci-status:v1
{"schema":"onix.radicle-ci-status.v1",...}
```

Only one matching status authored by the configured non-delegate bot is accepted for a job. Unknown fields, repeated/malformed markers, identity drift, failed dispositions, wrong authors, weakened status identity, missing signed refs, feature levels below `parent`, and signed candidate drift fail closed.

## Non-claims

The guard does not establish Radicle protocol-enforced mandatory CI, bypass-proof delegate behavior, Git or COB merge semantics, CI/source/Nix correctness, host sandboxing, canonical authority for the bot/runner/seeds/Valence, seed convergence, replication, release readiness, or post-update durability. It proves only that one operator invocation observed and optionally atomically applied the exact bounded facts named in its receipt.
