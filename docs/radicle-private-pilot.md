# Private Radicle repository pilot

## Current fixture

The pilot repository is a non-secret fixture. It checks Radicle 1.9.1 private visibility without placing production source or credentials at risk.

| Fact | Accepted value |
|---|---|
| RID | `rad:z3t9ykR1HfG9UkyKoQQg5ikkzrTxg` |
| Visibility | `private` |
| Reviewed commit | `ff4ff027817465b1bb04251a8a98db42cc610b0c` |
| Source archive BLAKE3 | `514904bdcf5f23b0813c567efbc8b6732248de94482037a58011bfff3fc26853` |
| Current identity revision | `cb3f6273f35ff437e58f15332d48f25b06c4b9cc` |
| Identity root | `bf5e168201192881cf34e9ff7f7c39ee42dc7d62` |
| Current identity JSON BLAKE3 | `f1794d2561882dd471541c2b4aff7392a12a3c08de81d974ace2e15009e1f2ab` |
| Current delegate signed refs | `ad1b6d032b69a4b81910b2fc98f8707b9ff268fb` |
| Delegate | `did:key:z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx` |
| Authorized client | `did:key:z6MkwGV7ypRii8RjoSotmUbuKU4MwGQf3iw8AdhuJkkyD4wd` |
| Denied client | `did:key:z6MksVCc4QAvmZrZXX2MWoGwo9XqDUbiFjsjDZuRZrbgEu6h` |

The current privacy set contains these identities:

- Aspen1 seed `did:key:z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8`
- desktop seed `did:key:z6MkkQCj5EczNiVzDzCkX9ewHNJ7NDEXSKbuRiS1x7o72yeG`
- `aspen3` seed `did:key:z6MkoHdimfedLwXjNZhxfAadc8H3rW2TMjpn7ATMNcRWieWh`
- the isolated authorized client DID

The denied client remains absent. Delegate access is inherent to repository governance.

## Evidence scope

`evidence/radicle/private-pilot-v1.json` is the accepted baseline receipt from `2026-07-25`.

That receipt binds identity revision `7fe3c9bd6a2d01a8317acb44ba386988375898da`. Its BLAKE3 is `966a76b31d40bf4eaa6d530b7e2b2f18ba457341ff126d799e7316213979e8a0`.

The `aspen3` deployment evidence records the later identity update and three-seed convergence. It does not rewrite the historical baseline receipt.

## Admission boundary

`seedRepositories` contains the exact four public RIDs. `privateSeedRepositories` contains only the private pilot RID.

The policy reconciler combines these sets only for native Radicle seeding. Public HTTPS Git and CI policy exclude the private RID.

Each seed service retains only its machine-scoped node key and repository storage. Private admission grants no repository governance authority to a seed service.

## Current checks

All three seed stores contain:

- identity revision `cb3f6273f35ff437e58f15332d48f25b06c4b9cc`
- delegate signed refs `ad1b6d032b69a4b81910b2fc98f8707b9ff268fb`
- canonical `main` commit `ff4ff027817465b1bb04251a8a98db42cc610b0c`

The baseline receipt covers direct authorized and denied client probes against Aspen1 and the desktop seed.

The `aspen3` deployment checks prove identity-authorized storage. They do not claim a new isolated-client confidentiality drill against `aspen3`.

## Incident response

Remove the private RID from each affected seed assignment. Then build the focused checks and deploy the affected machines.

Run policy reconciliation after deployment. Make sure that the private RID remains absent from HTTPS and CI policy.

Unseeding does not delete stored bytes. Preserve redaction-safe evidence before you approve storage or archive retirement.

## Non-claims

This fixture does not prove production-secret confidentiality, traffic-analysis resistance, global metadata secrecy, anonymity, or secure deletion.

It also does not prove automatic failover, geographic independence, source correctness, protocol-enforced CI, or release readiness.
