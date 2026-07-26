# Declarative execution-graph source deployment

Observed: 2026-07-25

## Scope

This record supersedes only the runtime-deployment limits in `staged-deployment-and-probes-2026-07-25.md`.

It does not supersede the governance, catalog, consumer, correctness, or release blockers.

## Current host generations

Aspen current system:

`/nix/store/d4awq19c4wr91la292zpxgligyy40xxn-nixos-system-aspen1-26.11.20260629.7a1a647`

Desktop current system:

`/nix/store/vgz9q9in8wlgxqw74mjh1l73yl32rvr4-nixos-system-britton-desktop-26.11.20260629.7a1a647`

Both hosts have earlier system generations available for rollback.

## Store-backed policy

Aspen policy unit:

`/nix/store/hjdb34sb36dh5jd9q30lnxlyd69rlha7-unit-radicle-policy-reconcile.service/radicle-policy-reconcile.service`

Desktop policy unit:

`/nix/store/yshqi703l9w1mfiscq387dd4xpsx2zkj-unit-radicle-policy-reconcile.service/radicle-policy-reconcile.service`

Each unit gives the reconciler the same exact four-RID live policy. It preserves the existing bounded-exec, artifact-auth, and private repository policies. It adds:

`rad:z2oYsb9jGTyp68BKYhzpivY1eK58a`

The declared policy timers are active on both hosts. A direct read-only query of each `policies.db` returned scope `all` and policy `allow` for execution-graph.

## Store-backed HTTPS route

Aspen Nginx unit:

`/nix/store/aswba80rpgqgcp1x2zw4j16d83mlrni8-unit-nginx.service/nginx.service`

Nginx configuration:

`/nix/store/0gxhn5qfvsy63q2lbbnxrxlscz1x9q0w-nginx.conf`

The Nix-store configuration contains exact execution-graph upload-pack routes. It rejects other discovery services and non-GET discovery methods.

The endpoint remained available after the system switch:

`https://git.onix.computer/z2oYsb9jGTyp68BKYhzpivY1eK58a.git`

## Source and probes

- Reviewed commit: `03736f1ec46c377ff86b451260ad68aa70ff3b0b`
- Source archive BLAKE3: `4b5aa3756369236fc82fbbf501d35993cfa208f142694cdd30ca370d6241192c`
- Fresh Aspen native acquisition: passed
- Fresh desktop native acquisition: passed
- Fresh HTTPS acquisition: passed
- Aspen-only outage acquisition: passed
- Desktop-only outage acquisition: passed
- Undeclared RID, receive-pack, wrong-service, root, and missing-object probes: rejected

## Authority blocker

The producer identity still has one delegate and threshold one. The accepted target remains three delegates and threshold two.

OnixOS catalog revision `8e0af634998c34e171b2e9771e7a496a9df98186` remains pending.

This deployment proves only observed host configuration and source service. It does not grant producer governance, catalog authority, consumer cutover, graph correctness, release readiness, or whole-stack GitHub independence.
