# Replica static peers delta

## MODIFIED Requirements

### Requirement: Replica configuration is typed and bounded

r[onix.radicle_replica.configuration] `onix-core` MUST validate and deterministically lower each selected replica host from an exact reviewed host matrix without enabling HTTP or repository governance authority. A replica MAY declare a static peer set naming only the Aspen1 seed and other reviewed replicas; a non-empty set MUST lower to Radicle `node.connect` with `node.peers.type = "static"`, and an empty set MUST leave the dynamic peer set unchanged.

#### Scenario: Reviewed replica configurations are admitted

r[onix.radicle_replica.configuration.accepted]
- GIVEN the reviewed package and exact host facts for `britton-desktop` or `aspen3`
- WHEN the replica configuration is evaluated
- THEN it MUST lower one hardened default-block Radicle node and authoritative policy reconciler
- AND it MUST use the reviewed target, failure domain, dataset, tailnet listener, exact repository sets, monitoring, quota, fingerprint, and signed-reference policy
- AND `britton-desktop` MUST lower static peers Aspen1 and Aspen3 while `aspen3` keeps the dynamic peer set
- AND it MUST enable no HTTP, HTTPS, Cloudflare, ACME, delegate, CI, deployment, release, canonical-ref, cache-write, backup, or artifact-administration input

#### Scenario: Unsafe replica configuration is rejected

r[onix.radicle_replica.configuration.rejected]
- GIVEN an unknown host, mismatched reviewed fact, Aspen1 identity reuse, weak signed refs, unsafe listener, invalid RID, missing monitoring, unbounded storage, an unreviewed or duplicate static peer, or a static peer naming the host itself
- WHEN validation runs
- THEN evaluation MUST fail with a stable diagnostic before deployment
