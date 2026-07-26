# Radicle CI runner

Deploys a non-delegate Radicle bot and a separate credentialless runner for the
single public Bounded Exec pilot RID.

The bot may synchronize the admitted RID and publish patch comments in its own
namespace. The runner receives immutable source archives through a group-bounded
spool, has no bot or production Radicle credentials, has no network, uses an
offline per-runner Nix store, and executes only the accepted bounded command.

The vendored `ci-policy-v1.json` is copied from OnixOS policy
`fixtures/radicle/ci-policy-v1.json` with BLAKE3
`091e57f4409f79db14465ccc26e730bf1181209fe45c28d7dd1259393e93f740`.
It is a deployment input and does not transfer correctness, merge, release,
artifact-durability, or protocol-enforcement claims to this module.

Patch status comments now begin with the visible protocol line `onix-radicle-ci-status:v1` and one closed JSON line binding the exact policy, patch revision, check, job, object, artifact, event, and result identities. The visible marker is intentional: Radicle CLI removes editor-only HTML comments before signing the built-in comment. The enclosing built-in Radicle comment is signed by the non-delegate bot. This remains job status only.

The package also contains an explicit operator command, `radicle-ci-runner guard`. No systemd service invokes it, and the bot/runner services remain unable to access `/var/lib/radicle`. The command independently loads a selected repository, verifies the signed status, exact delegate reviews, and threshold delegate `parent` signed refs naming the candidate, consumes a Valence admission receipt, previews by default, and only uses an expected-old atomic canonical compare-and-swap with `--execute`. See [`../../docs/radicle-forge-ci-guard.md`](../../docs/radicle-forge-ci-guard.md).
