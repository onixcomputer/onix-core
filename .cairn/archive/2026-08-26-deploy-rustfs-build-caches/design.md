# Design: RustFS-backed build caches

## Architecture

A pure Nix component defines bucket-scoped S3 policy documents. Two Clan services own separate imperative shells:

- `kache-rustfs` provisions `onix-kache`, runs the Kache daemon as `brittonr`, and keeps credentials in a user-readable Clan secret.
- `niks3` provisions `onix-niks3`, runs the upstream NixOS module on `aspen1`, and shares only its upload API token with fleet uploaders.

RustFS administration remains in short-lived provisioning units. Runtime services receive only bucket-scoped credentials.

## Kache boundary

The Home Manager Cargo wrapper keeps `/var/cache/kache-nix/user-brittonr` as its local store. Its typed config selects the desktop RustFS endpoint and disables strict local-only mode. A system service owns remote checks and uploads with an environment file. The Nix sandbox wrapper remains `KACHE_LOCAL_ONLY=1`; it does not receive network authority or credentials.

## Niks3 boundary

Niks3 `v1.8.0` comes from the pinned Nixpkgs package. The reviewed upstream `v1.8.0` NixOS modules are fetched by immutable tag and hash. The server uses local PostgreSQL for reference tracking and RustFS for NAR data. Its read proxy binds `100.100.103.95:39400` and the firewall admits that port only on `tailscale0`.

A dedicated signing generator writes an encrypted secret and a public value. Client roles trust the public key. A separate shared API token feeds root-owned auto-upload daemons on all three RustFS nodes.

## Failure and rollback

Kache falls back to normal compilation when remote storage is unavailable. Niks3 clients fall through to other substituters when its read proxy is unavailable. Disabling the two service instances stops new uploads without deleting either bucket. Existing Harmonia remains available during the trial.

## Verification

Pure settings tests reject unsafe endpoints, public firewall settings, empty buckets, missing provisioners, and invalid durations. Generated checks inspect credentials, service ownership, Tailnet firewall scope, Kache's local-only sandbox boundary, Nix trust, and auto-upload composition. Runtime evidence covers narrow IAM, upload/read round trips, restarts, and unauthorized requests.
