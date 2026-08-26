# Celld RustFS Runtime Rollout Evidence

Date: 2026-08-25

## Scope

This evidence covers one private Celld `v0.3.0` lab fleet on `aspen1`, `aspen3`, and `britton-desktop`. The fleet uses the existing three-node RustFS cluster and runs one deterministic counter Worker.

## Immutable package

The Nix package downloads the official `celld-x86_64-unknown-linux-gnu.gz` artifact from the immutable `v0.3.0` release. Nix verifies the published SHA-256 digest `cbfcfa5f6d7551b5316f6f4c9d7751c741a9ba2a2305dde8d5cb4d1b37fb34a6`. The packaged executable reported `celld 0.3.0`.

## Storage qualification

Before implementation, Celld diagnosis passed through each RustFS endpoint:

- conditional create succeeded;
- duplicate create was rejected;
- conditional update succeeded; and
- stale update was rejected.

A second pre-implementation probe created a temporary RustFS user and bucket-scoped policy. Celld passed the same fencing test with that user. The temporary user, policy, and bucket were removed.

The deployed provisioner created bucket `onix-celld-lab`, user `celld-lab`, and policy `celld-celld-lab`. The policy grants S3 actions only on the fleet bucket and its objects. The dedicated credential could read its own bucket. It could not read a temporary foreign bucket or create another bucket. The temporary foreign bucket was removed.

After the fleet stabilized, Celld diagnosis passed the complete conditional-write probe through all three RustFS endpoints. Each diagnosis also completed signed direct probes of all three live Celld peers.

## Deployed systems

- Aspen1: `/nix/store/7h4p7acq6cqzx875j6b0c21p8znkhd92-nixos-system-aspen1-26.11.20260819.afe3d8a`
- Aspen3: `/nix/store/920zs83x8g12gk5b2xxvjbxs9v8w8p5l-nixos-system-aspen3-26.11.20260819.afe3d8a`
- Desktop: `/nix/store/x6qk1adcyjrvmxy0j5y8fn32ld5k9lrd-nixos-system-britton-desktop-26.11.20260819.afe3d8a`

All nodes bound only their explicit Tailnet addresses on ports `39200` and `39201`. Each `/var/lib/celld-lab` directory was owned by `celld:celld` with mode `0700`. Each deployed credential file was owned by `celld:celld` with mode `0400`.

The Aspen1 provisioner completed successfully and remained active as an exited oneshot. RustFS administrator credentials were present only in that oneshot. The Celld services received only the shared bucket credential.

## Durable counter

The first request through Aspen1 returned counter value `1`. Sequential requests through Aspen1, Aspen3, and the desktop returned `2`, `3`, and `4`. This proved one counter lineage through all public listeners.

A coordinated service restart started from value `8`. After all three nodes returned healthy, the next request returned `9`.

Aspen3 then stopped for longer than one lease lifetime. Aspen1 and the desktop returned values `10` and `11`. After Aspen3 rejoined, a request through Aspen3 returned `12`. The final request through Aspen1 returned `13`.

## Clock incident and correction

The first three-node run exposed approximately 140 seconds of clock skew. The desktop clock was ahead of the two Aspen hosts. Celld on the desktop therefore treated valid Aspen leases as expired. Aspen1 and Aspen3 rejected later lease updates and self-fenced as designed.

Systemd-timesyncd was active on the desktop, but `networkctl` reported its NetworkManager-managed links as offline. Timesyncd sent no packets. The desktop now uses Chrony, whose NixOS module includes a NetworkManager dispatcher and supports the configured local-time RTC.

After Chrony started, all three epochs agreed within one second. A 90-second observation showed no new automatic restart on any node. The final 60-second observation reported every Celld service active with `NRestarts=0` before and after the interval.

The clock incident left 94 expired node lease records in the fleet bucket. Celld diagnosis ignored them and reported exactly three live signed peers. This change does not claim that Celld automatically removes historical lease records.

## Provisioning repairs

The first provisioning attempt showed that MinIO Client requires `getent` in its service path. The second showed that its config directory must be set through `MC_CONFIG_DIR` inside the hardened service. The third showed that the Worker project must be a direct Nix closure dependency. Each issue was fixed declaratively before the successful rollout.

## Final state

All three Celld health endpoints returned `{"ok":true}`. All services were active, all listeners remained Tailnet-only, and the counter retained one durable lineage through restart and node loss.

## Final validation

Cairn structural validation passed after sync and archive. The focused Celld checks and all three complete NixOS system builds passed.

The repository-wide Tracey command reported zero references for all 394 accepted requirements. The selected policy scans Rust and Nickel files only under `crates/` and `tools/`. This Nix configuration repository has no evidence roots in that profile, so the result is a repository policy coverage gap rather than failed Celld runtime evidence.

## Non-claims

- Celld `v0.3.0` is alpha software and is not safe for hostile multi-tenant use.
- RustFS distributed mode remains experimental in `1.0.0-rc.2`.
- This evidence does not prove public ingress safety, long-duration load behavior, total-cluster disaster recovery, or future-release compatibility.
- The controlled `systemctl stop` outage does not prove every abrupt process, kernel, storage, or network failure mode.
- Tailnet membership remains the access boundary for the internal operator listener.
