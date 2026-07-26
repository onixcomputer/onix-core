# Private Radicle repository pilot

## Accepted fixture

The pilot repository is a non-secret fixture. It proves the selected Radicle 1.9.1 private-visibility mechanism and Onix admission boundary without placing production source or credentials at risk.

| Fact | Accepted value |
|---|---|
| RID | `rad:z3t9ykR1HfG9UkyKoQQg5ikkzrTxg` |
| Visibility | `private` |
| Reviewed commit | `ff4ff027817465b1bb04251a8a98db42cc610b0c` |
| Source archive BLAKE3 | `514904bdcf5f23b0813c567efbc8b6732248de94482037a58011bfff3fc26853` |
| Identity revision | `7fe3c9bd6a2d01a8317acb44ba386988375898da` |
| Identity root | `bf5e168201192881cf34e9ff7f7c39ee42dc7d62` |
| Delegate | `did:key:z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx` |
| Authorized client | `did:key:z6MkwGV7ypRii8RjoSotmUbuKU4MwGQf3iw8AdhuJkkyD4wd` |
| Denied client | `did:key:z6MksVCc4QAvmZrZXX2MWoGwo9XqDUbiFjsjDZuRZrbgEu6h` |
| Evidence receipt | `evidence/radicle/private-pilot-v1.json` |
| Receipt BLAKE3 | `966a76b31d40bf4eaa6d530b7e2b2f18ba457341ff126d799e7316213979e8a0` |

The private identity privacy set contains only the Aspen node, the desktop replica, and the isolated authorized client. Delegate access is inherent to repository governance. The denied client is absent.

## Admission boundary

`seedRepositories` remains the exact public Bounded Exec, artifact-auth, and execution-graph set. `privateSeedRepositories` is a separate exact set containing only the private pilot RID. The policy reconciler combines both sets only for native Radicle seeding.

The public HTTP explorer receives no private pin. Nginx and `git.onix.computer` are generated only from `httpsGitRepositories`, which remains the exact three-public-RID set. The CI policy remains scoped only to Bounded Exec.

Every admitted seed retains only its machine-scoped Radicle node key and repository storage. Private admission does not grant delegate, canonical-ref, CI, deployment, release-signing, cache-write, backup administration, Cloudflare, user-profile, or secret authority.

## Acceptance probes

Use fresh isolated client profiles. Connect each profile directly to one reviewed seed before cloning with the seed NID and signed-reference feature level `parent`.

Acceptance requires:

1. Aspen and the desktop each store the exact identity revision, delegate namespace `main`, signed refs, and canonical commit.
2. Fresh authorized clients cloning independently from Aspen and the desktop reproduce the reviewed commit and source BLAKE3.
3. Fresh unauthorized clients do not see the RID in remote inventory and fail the private fetch handshake without creating a checkout.
4. The private upload-pack and receive-pack HTTPS routes return `404`, while an admitted public upload-pack route remains healthy.
5. The encrypted off-site backup succeeds, clean-root restore verification succeeds, and the restored private repository reproduces the exact reviewed object and source hash.
6. Both policy reconcilers report an exact desired count of three without widening the CI or HTTPS allowlists.

## Incident response

Remove the RID from `privateSeedRepositories` on both seed roles, rebuild both focused checks and machine closures, deploy both reviewed targets, and run policy reconciliation. Confirm the private RID is absent from native policy and remains `404` over HTTPS. Preserve redaction-safe evidence before deciding whether repository bytes and encrypted archives may be retired; unseeding alone is not secure deletion.

## Non-claims

This fixture does not prove confidentiality for production secrets, traffic-analysis resistance, global metadata secrecy, anonymity, multi-delegate private governance, secure deletion, automatic failover, geographic independence, protocol-enforced CI, source correctness, or release readiness. An inventory non-disclosure observation is bounded to the tested Radicle version, identities, seeds, and direct acquisition path.
