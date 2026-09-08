# Drift RustFS deployment — 2026-09-07

This receipt records the initial storage rollout. `drift-playback-2026-09-07.md` records the later repairs and current deployed build.

## Result

Drift storage is active on `britton-desktop`. The verified system is also the boot default. No reboot was necessary.

- Published Drift revision: `acb608912d01fc5ac96bcef4aeed0c8532a386ac` on `origin/main`.
- Previous system: `/nix/store/809lx8nxs26rkc53czi4z9cpfn5npc9l-nixos-system-britton-desktop-26.11.20260819.afe3d8a`.
- Active system: `/nix/store/w9k69nc08jdpxqm8m8gsirjjwg9fnplc-nixos-system-britton-desktop-26.11.20260819.afe3d8a`.
- RustFS endpoint: `http://100.110.43.11:39000`, through the existing private cluster.
- Bucket: `onix-drift`.
- Account prefix: `drift/v1/users/brittonr/`.
- Metadata mode: direct S3 conditional writes. No Celld deployment changed.

The release came from the isolated `../drift-release` worktree. The original Drift checkout and its twelve staged files remain unchanged.

## Verification

The isolated release passed both Cargo feature matrices and `nix flake check`. The Onix system build and `drift-rustfs-policy` check passed.

The live probe ran as `brittonr` with the deployed client credentials. It passed all eight checks:

1. An absent permitted object returns HTTP 404.
2. Conditional creation succeeds.
3. Object retrieval succeeds.
4. Retrieved content matches the original payload.
5. Duplicate conditional creation returns HTTP 412.
6. A stale conditional update returns HTTP 412.
7. Access to another account prefix returns HTTP 403.
8. Object deletion returns HTTP 403.

The probe leaves one small, unindexed object under the account's `blobs/` prefix. It does not change account metadata or audio indexes.

`drift-rustfs-provision`, RustFS, MPD, and `qwen38-p150x2` were active after the final switch. The activation diff removed no unrelated packages or secrets. Existing failed backup and cleanup units were outside this deployment.

The initial provisioning attempt lacked `getent` in its command path. The module now declares that dependency. Provisioning and live verification passed after the correction.

## Use

Run `drift` or `drift-sync` from the system command path. Their wrappers load the protected Clan credential file automatically. No manual credential export is necessary.

The deployed credential file has mode `0400` and owner `brittonr`. The generated client configuration enables sync for device `britton-desktop`.

Existing local audio is not automatically uploaded. New downloads enter the replication queue. This receipt does not claim a production reboot test, audio playback test, or old-cluster data migration.

## Source status

The Drift release is published. The Onix pin, module integration, and encrypted generated secret remain local changes alongside the existing Onix work. No unrelated staged changes were committed or pushed.
