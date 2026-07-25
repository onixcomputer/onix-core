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
