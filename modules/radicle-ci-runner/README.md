# Radicle CI runner

Deploys a non-delegate Radicle bot and a separate credentialless runner for the
single public Bounded Exec successor RID `rad:zG25DRmacxYQcXzZmLKj8tmgYbEG`.

The bot may synchronize the admitted RID and publish patch comments in its own
namespace. The runner receives immutable source archives through a group-bounded
spool, has no bot or production Radicle credentials, has no network, uses an
offline per-runner Nix store, and executes only the accepted bounded command.

The vendored `ci-policy-v1.json` is a byte copy of OnixOS policy
`fixtures/radicle/ci-policy-v2.json` with BLAKE3
`ab4e2ae72b22c4c2704aca88852e4e5f036c2ca7501d257d11bec8827af2ebb3`; it differs
from OnixOS `ci-policy-v1.json` only in the repository RID.
It is a deployment input and does not transfer correctness, merge, release,
artifact-durability, or protocol-enforcement claims to this module.

Patch status comments now begin with the visible protocol line `onix-radicle-ci-status:v1` and one closed JSON line binding the exact policy, patch revision, check, job, object, artifact, event, and result identities. The visible marker is intentional: Radicle CLI removes editor-only HTML comments before signing the built-in comment. The enclosing built-in Radicle comment is signed by the non-delegate bot. This remains job status only.

The package also contains an explicit operator command, `radicle-ci-runner guard`. No systemd service invokes it, and the bot/runner services remain unable to access `/var/lib/radicle`. The command independently loads a selected repository, verifies the signed status, exact delegate reviews, and threshold delegate `parent` signed refs naming the candidate, consumes a Valence admission receipt, previews by default, and only uses an expected-old atomic canonical compare-and-swap with `--execute`. See [`../../docs/radicle-forge-ci-guard.md`](../../docs/radicle-forge-ci-guard.md).

The guard profile stays bound to the frozen pilot RID `rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo`. It is retired for the successor RID while that identity has one delegate at threshold 1, because Radicle then moves canonical `main` on every delegate push; `onix/ci/v1` status for the successor is evidence only. `modules/radicle-forge-guard/contracts.ncl` records the reason and the reinstatement condition.
