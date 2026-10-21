## Why

Replace per-client SSH dispatch to Aspen1 with an authenticated, shared gRPC build farm. The user explicitly selected full scheduling and automatic farm output publication rather than the transport-only option.

## What Changes

- Admit Aspen1 as scheduler, balancer, and worker; admit Aspen2 as a second worker.
- Route Bonsai, Aspen3, and britton-desktop through `aspen1.local:50051`, preserving independent SSH targets and the exclusion of the unreachable Darwin host. Exclude britton-fw at the user's request.
- Authenticate clients, workers, and the balancer using role-specific Clan-managed certificates and exact identities.
- Publish successful farm outputs automatically to the isolated Niks3 cache with bounded upload concurrency. Keep non-farm post-build queues maintenance-only.
- Build the gRPC plugin against the existing Nix fork without advancing its pin.
- Complete the subsequently authorized desktop build prerequisite repairs: adapt existing Tenstorrent consumers to their pinned SDK without repinning inputs, disabling diagnostics, or changing managed accelerator service ownership.

## Impact

- **Files**: the targeted flake inputs and package output, `modules/nix-build-farm`, service registries and inventory, remote-builder routing/checks, cache compatibility assertion, and existing cache operator guidance.
- **Testing**: build the pinned plugin and cache packages; evaluate generated client, worker, firewall, credential and queue boundaries; run a bounded real scheduled-build/cache/authentication smoke; validate the native Cairn change.
- **Deployment prerequisites**: build all five complete system closures, recover authenticated Aspen1 access, and preserve a verified Niks3 database backup before switching the primary. Record host-only compatibility checks separately from live farm or accelerator evidence.
