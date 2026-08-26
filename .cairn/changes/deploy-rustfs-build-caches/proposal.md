# Deploy RustFS-backed build caches

## Problem

The desktop Kache service is local-only, and the fleet has no durable binary cache independent of one machine's Nix store. RustFS now provides private distributed object storage, but build tools do not use it.

## Proposed change

- Give interactive Kache a dedicated RustFS bucket, principal, background daemon, and operator sync command on `britton-desktop`.
- Deploy Mic92/niks3 `v1.8.0` on `aspen1` with a separate RustFS bucket and local PostgreSQL metadata.
- Serve niks3 reads and writes only through its Tailnet listener.
- Enable crash-safe niks3 auto-upload on `aspen1`, `aspen3`, and `britton-desktop`.
- Add the niks3 read proxy and dedicated signing key to Nix trust on those machines.
- Keep the sandboxed Nix Kache pilot local-only because Nix builders do not receive object-store credentials.

## Success

Kache can push artifacts to its narrow RustFS bucket. Niks3 can upload a unique store path, serve it to another node, survive restart, and reject unauthenticated writes. Both services pass typed, generated, negative, and full-machine checks.

## Non-goals

- Remove Harmonia.
- Expose either cache outside the Tailnet.
- Give Kache or niks3 RustFS administrator credentials.
- Put PostgreSQL state in RustFS.
