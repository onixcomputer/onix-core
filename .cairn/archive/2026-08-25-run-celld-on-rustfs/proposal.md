## Why

The private RustFS cluster now provides one shared S3-compatible namespace, but no deployed application consumes its conditional-write contract. Celld can provide self-hosted Durable Objects only when its object store correctly rejects duplicate creates and stale updates. A live Celld `v0.3.0` probe passed those operations through every RustFS node, so a bounded private fleet can now validate the complete application path.

## What Changes

- Package the immutable Celld `v0.3.0` release binary with its published SHA-256 digest.
- Add a typed Clan Celld service with explicit public, internal, storage, state, and provisioning settings.
- Compose one three-node Celld lab fleet on `aspen1`, `aspen3`, and `britton-desktop`.
- Generate one encrypted fleet credential, provision one dedicated RustFS bucket and bucket-scoped policy, and keep RustFS administrator credentials out of the Celld service.
- Bind Worker and peer listeners only to Tailnet addresses and admit their ports only on `tailscale0`.
- Deploy a deterministic counter Worker for cross-node persistence and failover acceptance.

## Impact

- **Files**: `.cairn/changes/run-celld-on-rustfs/`, `pkgs/celld/`, `flake-outputs/tools.nix`, `modules/celld/`, module registries, service inventory, and focused fixtures/checks.
- **Testing**: package execution, positive and negative settings checks, generated-service checks, Celld storage diagnosis, cross-node counter requests, restart persistence, one-node loss, recovery, Cairn validation, and all affected NixOS builds.
