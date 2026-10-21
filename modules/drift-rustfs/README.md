# Drift on RustFS

This module provisions a dedicated `onix-drift` bucket on the existing RustFS cluster. It does not replace RustFS or deploy Celld.

`config.ncl` owns the account and endpoint configuration. `policy.nix` permits only object reads and writes for the account snapshot and blobs. It grants no bucket listing, object deletion, or access to other account prefixes.

The Clan generator stores client credentials as an encrypted secret. Only `brittonr` and root can read the deployed file. The `drift` and `drift-sync` wrappers load that file at runtime. No credential value enters the Nix store or Home Manager configuration.

## Deployment gate

The desktop configuration enables this module. The Drift input pins the published S3 release `bb8c23f97c37bb48775d96699a2a1b8dbe26f8be`.

1. Publish the verified Drift S3 migration without unrelated staged changes.
2. Pin that revision through Nix in `flake.nix` and the generated `flake.lock`.
3. Enable `services.drift-rustfs.enable` on `britton-desktop`.
4. Generate the `drift-rustfs-brittonr` Clan secret.
5. Build the desktop system.
6. Review the activation diff for unrelated service changes.
7. Deploy the secret and activate the verified system.
8. Verify account-scoped writes, reads, conditional-write rejection, and denied access outside the account prefix.

The module rejects activation configuration with a Drift input that lacks the `s3` feature. A temporary local input override is not a durable release pin.

Existing local audio is not automatically uploaded. New downloads enter the replication queue after activation. Existing pending operations must retain their account and device identity.

## Playback dependencies

The Drift wrappers use yt-dlp `2026.08.19` from immutable upstream revision `3a08beaf031ab68f966401ead017ac81fe8486cf`. The system-wide yt-dlp package is unchanged.

The July extractor returned audio URLs that failed with HTTP 403. The pinned August extractor passed the same track through Drift and MPD.

Drift accepts credentials from its previous `tidal-tui` directory when its own credential file is absent. Successful token refreshes use private, atomic writes in the Drift directory.

Physical sound still requires an available output device. Playback verification distinguishes decoded audio from physical speaker output.

## Verification

`tests.nix` covers the exact allowed actions and resources. It rejects wildcard accounts, path traversal, empty buckets, and malformed prefixes.

RustFS health and root SSH access passed. Before provisioning, the dedicated bucket and account did not exist. Deployment evidence belongs in the deployment receipt, not this configuration guide.
