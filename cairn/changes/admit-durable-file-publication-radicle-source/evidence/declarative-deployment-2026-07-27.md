<!-- r[verify onix.radicle_source_admission.deployment] -->
<!-- r[verify onix.radicle_source_admission.probes] -->

# Declarative durable-file-publication source deployment

Observed: 2026-07-27

## Scope

This record binds one reviewed Radicle source to the existing Onix-managed primary seed, native replica, and read-only HTTPS endpoint. It does not grant consumer, correctness, release, retention, recovery, or deletion authority.

## Bound source

- RID: `rad:z3tAR4For7qw8ZirkJzoDw1VNDDLM`
- Reviewed commit: `951c27f59003cea9bfdb40ed4d89653d50fada1f`
- Source archive BLAKE3: `2c1d8b5adc8d7384f48a6f8336165e38c3eb196337ebbd66707e157a64b63210`
- Identity revision: `8d6d95454c09449708e687b51e80c787750e75e3`
- Publisher signed refs: `8aa111383236ef76578edb18dbc5410395a42763`
- Delegate: `did:key:z6MksnXbFoE8zkCkGWhHc8zuxpnEUhrJHv2KECRV4GSv9gkx`
- Threshold: one
- Signed-reference feature: `parent`
- Producer Cairn archive receipt: `3a11ed34c922a32678f4e5e72bd9ea48b3e3d0eba35edf0c821c27f5a7920fe4`

## Store-backed deployment

Aspen1 current system:

`/nix/store/j2mvzq86wwdrgna1972av3cm868rq9ni-nixos-system-aspen1-26.11.20260629.7a1a647`

Britton-desktop current system:

`/nix/store/8zr3fdh5sf16d8bxjpgkgc4cg1m9snid-nixos-system-britton-desktop-26.11.20260629.7a1a647`

Both hosts run enabled `radicle-node.service` and `radicle-policy-reconcile.timer` units. Reconciliation completed with `desired=5`: four public RIDs and one separately managed private RID. No runtime systemd override is present.

Aspen1 kept node ID `z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8`. Britton-desktop kept node ID `z6MkkQCj5EczNiVzDzCkX9ewHNJ7NDEXSKbuRiS1x7o72yeG`.

Aspen1 acquired the repository through Radicle after policy reconciliation. Britton-desktop received a checksum-verified private-SSH storage bootstrap because earlier direct fetch handshakes reset. Both stores passed `git fsck --full --strict` and resolved `main` and publisher signed refs exactly.

## Exact acquisition probes

Fresh ephemeral Radicle profiles used separate state roots and the `parent` signed-reference feature.

- Aspen native acquisition: commit and source BLAKE3 matched.
- Britton-desktop native acquisition: commit and source BLAKE3 matched.
- Aspen public HTTPS acquisition: commit and source BLAKE3 matched.

The public read-only endpoint is:

`https://git.onix.computer/z3tAR4For7qw8ZirkJzoDw1VNDDLM.git`

## Rejection and authority probes

- Upload-pack discovery returned HTTP 200.
- Receive-pack discovery returned HTTP 404.
- An undeclared RID returned HTTP 404.
- The endpoint root returned HTTP 404.
- A wrong Git service returned HTTP 404.
- A missing Git object was rejected.
- Both node units run as `radicle` with `ProtectHome=yes`, `NoNewPrivileges=yes`, and an empty capability bounding set.
- Both services retain only their machine-scoped Radicle node credentials. The producer delegate key is absent.

## Deployment note

The normal Aspen1 Clan deployment passed. The desktop Clan command stopped at a stale system SSH host-key entry. The active desktop key was independently read from the local SSH server as `SHA256:KKaXLR31kODMGkmFO/qoOxTokzrGkhbRXOPCRPj6QoE`. A temporary exact-key known-hosts file then protected manual `nix copy` and profile activation. Strict host-key checking remained enabled.

## Non-claims

This evidence does not prove library correctness, payload truth, consumer adoption, release readiness, geographic independence, automatic HTTPS failover, Radicle-only replica bootstrap, permanent network availability, retention, recovery, garbage collection, or deletion authority.
