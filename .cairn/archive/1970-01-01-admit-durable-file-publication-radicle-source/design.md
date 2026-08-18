# Design: durable-file-publication Radicle source admission

## Policy model

One ordered public-source list contains Bounded Exec, `artifact-auth`, `execution-graph`, and `durable-file-publication`. Aspen1 native seeding, Aspen1 read-only HTTPS routes, and britton-desktop native seeding derive from that list. Bounded Exec keeps its separate CI policy.

The deployed hosts also carry a separately managed private RID. Public-source admission must preserve that policy without recording private repository content in public evidence.

## Producer identity

The admitted source binds RID `rad:z3tAR4For7qw8ZirkJzoDw1VNDDLM` to commit `951c27f59003cea9bfdb40ed4d89653d50fada1f`, source-archive BLAKE3 `2c1d8b5adc8d7384f48a6f8336165e38c3eb196337ebbd66707e157a64b63210`, identity revision `8d6d95454c09449708e687b51e80c787750e75e3`, publisher signed refs `8aa111383236ef76578edb18dbc5410395a42763`, one delegate, and threshold one. The source Cairn archive receipt is `3a11ed34c922a32678f4e5e72bd9ea48b3e3d0eba35edf0c821c27f5a7920fe4`.

## Validation core

Pure Nix validation requires exact ordered membership, canonical RID syntax, unique entries, the `parent` signed-reference feature, unchanged host identities, exact producer identity, and required non-claims. Negative cases cover a missing source, duplicate source, widened CI policy, weak governance, runtime-only deployment, accepted writes, and missing non-claims.

## Deployment shell

The existing Onix Core modules own state, machine identities, credentials, policy reconciliation, listeners, firewall rules, monitoring, and HTTPS lowering. Normal machine deployment replaces the current generations. No runtime systemd drop-in is sufficient evidence.

The managed node keys remain non-delegate machine identities. The producer delegate remains outside both services.

## Failure and rollback

If either managed node cannot acquire the reviewed object, do not accept the evidence. Roll back each host to its previous system generation. Keep repository storage intact. A host rollback restores the prior three-public-RID policy.

## Evidence

Typed Nickel evidence and deterministic JSON/BLAKE3 projections bind producer identity, exact policy, deployed closures, live policy observations, native and HTTPS probes, rejection probes, and non-claims. Evidence must not contain private keys or private repository content.
