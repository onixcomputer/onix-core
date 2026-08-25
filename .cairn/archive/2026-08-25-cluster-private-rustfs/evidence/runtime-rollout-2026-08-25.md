# RustFS cluster rollout evidence

## Scope

This evidence covers the live three-node RustFS cluster rollout and bounded runtime checks on 2026-08-25. It does not prove production maturity or geographic independence.

## Deployed systems

- Aspen1: `/nix/store/wijqys09q1p4n2gnk08w3f0lg6z1i4vc-nixos-system-aspen1-26.11.20260819.afe3d8a`
- Aspen3: `/nix/store/q8yn31msp8s3nrpf2lbkqxlhay9f0xyh-nixos-system-aspen3-26.11.20260819.afe3d8a`
- Britton desktop: `/nix/store/nc1i5jlwivf739l789xhvlkvkch5w58f-nixos-system-britton-desktop-26.11.20260819.afe3d8a`

All three nodes reported `rustfs.service` as active and running. Each health endpoint returned `ready: true` with RustFS `1.0.0-rc.2`.

## Rollout correction

The first partial switch exposed a hardening defect. RustFS could not verify its Tailnet bind address because `RestrictAddressFamilies` denied `AF_NETLINK`.

The rollout stopped before Aspen1 switched. A temporary runtime drop-in confirmed the cause. The module now admits `AF_NETLINK`, and the topology check verifies that all three generated services retain it. Focused checks and all three complete system builds passed before the rollout resumed.

The temporary runtime drop-ins were removed after the declarative fix was active.

## Storage and network boundary

The live cluster directories are:

- Aspen1: `/var/lib/rustfs-cluster`
- Aspen3: `/mnt/usb4-nvme/rustfs-cluster`
- Britton desktop: `/datapool/rustfs-cluster`

Each directory reported owner `rustfs:rustfs` and mode `0700`.

The API and console listeners used each node's explicit Tailnet address on ports `39000` and `39001`. No wildcard listener was observed. The previous Aspen3 and desktop standalone directories remain present and unchanged by the cluster tests.

## Namespace and authentication

One shared credential file was present on all nodes. BLAKE3 comparison proved file equality without printing the credential or its hash.

For each node in turn, the test created a bucket and wrote an object through that node. It then read and listed the object through all three nodes. All nine writer-reader combinations matched the source bytes. Each temporary bucket and object was removed.

Anonymous requests to all three S3 endpoints returned HTTP `403`.

## Coordinated restart

A retained object was created through Aspen1 and written through Aspen3. All three RustFS services then received a coordinated restart.

All health endpoints returned to ready state. The retained object matched through every endpoint after restart. Each service later reported `NRestarts=0`.

## One-node outage and recovery

Aspen3's RustFS service was stopped. Its health endpoint became unreachable.

While Aspen3 was offline:

- the retained object remained readable through Aspen1;
- a new object was written through Aspen1;
- the new object matched when read through the desktop endpoint.

Aspen3 then restarted and returned to ready state. The outage-written object matched through Aspen3. An authenticated heal check reported all three drives online and green, with no missing or corrupted drives.

The retained test bucket, objects, client binary, and client configuration were removed after verification.

## Final state

All three systems reported a running system state. All RustFS services were active, running, and had no warning-level journal entries during the final two-minute observation window.

Aspen1 briefly retained a failed Radicle CI runner state from the large generation switch. Its current runner configuration paths existed, so the stale failure state was reset without executing a job. Aspen1 then reported a running system state with no failed units.

## Final validation

Cairn structural validation passed after sync and archive. The focused RustFS checks and all three complete NixOS system builds also passed from the archived source snapshot.

The repository-wide Tracey command reported zero references for all 372 accepted requirements. The selected policy scans Rust and Nickel files only under `crates/` and `tools/`. This Nix configuration repository has no evidence roots in that profile, so the result is a pre-existing policy coverage gap rather than RustFS runtime evidence.

## Non-claims

- RustFS distributed mode remains experimental in `1.0.0-rc.2`.
- This test does not prove multi-building, regional, or power-failure independence.
- This test does not prove tolerance of two simultaneous node failures.
- This rollout did not migrate data from the retained standalone stores.
- This test does not provide a stable load-balanced client address.
