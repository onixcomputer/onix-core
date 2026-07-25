## Why

The accepted Aspen1 bootstrap receipt is intentionally single-node evidence. Bounded Exec publication and Lattice cutover require the exact governed RID to remain natively available from a second selective seed in a distinct machine/storage failure domain, without copying delegate, CI, deployment, release, canonical-ref, or cache-write authority into that service.

## What Changes

- Add a typed secondary-seed service boundary for `britton-desktop` with its own machine-scoped Radicle node identity, bounded ZFS state, default-block policy, exact pilot allowlist, interface-scoped listener, monitoring, and runtime fingerprint check.
- Reuse the reviewed Radicle packages and deterministic policy reconciler without enabling HTTP, public ingress, private repositories, backup authority, or repository governance.
- Deploy through the pinned tailnet target, synchronize only `rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo`, and prove exact-object acquisition plus Aspen1-off native availability from an independent client.
- Emit a redaction-safe deployment receipt for OnixOS catalog admission.

## Impact

- **Files**: secondary-seed Nickel/Nix module, inventory assignment, desktop ZFS dataset, focused positive/negative checks, deployment evidence, and operator documentation.
- **Cross-repo output**: OnixOS consumes the deployment receipt but retains catalog and wider-pilot acceptance ownership.
- **Security**: the service receives only its node key and public pilot repository; the host's user profiles, backup credentials, delegate artifacts, CI, deployment, release, signing, Cloudflare, cache, and repository authority remain inaccessible to the unit.
- **Non-goals**: this change does not create a second public HTTPS origin, geographic/building-power independence, private-repository confidentiality, CI, canonical-ref enforcement, source correctness, or release readiness.
