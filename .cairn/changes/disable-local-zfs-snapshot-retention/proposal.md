# Disable local ZFS snapshot retention

## Why

Clan's core module enables `services.zfs.autoSnapshot` on every managed machine, so britton-desktop and aspen3 both run `zfs-auto-snapshot` hourly, daily, weekly and monthly. Aspen3 additionally set an 8/7/4/1 keep window on `zroot/home`.

That local window filled the pool. On 2026-11-23 aspen3 reported `zroot/home` as unwritable with `usedbysnapshots` at 83.5 GiB even after deleting the 71 GiB Counter-Strike install; the space only returned after the 13 auto-snapshots were destroyed. Local snapshots are also the only copy of that data — nothing uploaded them off-machine.

## What changes

- Disable `services.zfs.autoSnapshot` on britton-desktop and aspen3, overriding Clan's `true` with `lib.mkForce false`.
- Remove aspen3's 8/7/4/1 keep counts and its explicit frequent-timer override, which only existed to shape the local policy.
- Keep dataset `com.sun:auto-snapshot` properties unchanged; they no longer create snapshots without the timers.

## What does not change

- General Borg jobs, their schedules and retention.
- The Radicle backup policy and RustFS/database recovery policy.
- Existing snapshots on aspen3's agent datasets; they are left in place.
- The encrypted Restic archives already on Drive.

## Risk

Local rollback points are no longer created. Recovery depends on the off-machine copies: Borg to aspen1 and the Restic archives on Drive. Aspen3's latest Borg archive is currently left with a `.failed` suffix, and no automated Drive job exists yet; both are recorded as remaining gaps, not solved here.
