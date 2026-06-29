## Context

`inventory/services/services.ncl` already declares a `store-maintenance` instance backed by `modules/nix-gc`. That module maps schema settings into stock NixOS `nix.gc`, `nix.optimise`, and `nix.settings.auto-optimise-store` options. Separately, `inventory/tags/common/shared-nix.nix` sets stock GC and optimization defaults for all platforms, while some NixOS tags override stock GC schedules or retention.

Upstream `fast-nix-gc` ships a NixOS module exposing `services.fast-nix-gc` and `services.fast-nix-optimise`. The module warns, but does not automatically disable, stock `nix.gc.automatic` or `nix.optimise.automatic`.

## Decisions

### 1. Integrate at the clan service wrapper

**Choice:** Import `inputs.fast-nix-gc.nixosModules.default` inside `modules/nix-gc` and render fast service options from the existing role settings.

**Rationale:** The inventory keeps using the existing `store-maintenance` service and tag targeting. Machines do not need a second service instance or manual module import.

### 2. Fast path on by default with fallback

**Choice:** Add `useFastGc` to the `nix-gc` schema with a default of `true`. When false, the module keeps rendering the stock `nix.gc` and `nix.optimise` timers.

**Rationale:** New deployments get the requested faster collector, while operators can fall back quickly if upstream behavior regresses on a machine.

### 3. Disable duplicate stock timers only in fast mode

**Choice:** When `useFastGc` is true, force `nix.gc.automatic = false` and `nix.optimise.automatic = false` while enabling `services.fast-nix-gc` and `services.fast-nix-optimise`.

**Rationale:** Upstream warns if both scheduled collectors are active. Forcing the stock timer off makes the fast path deterministic even with shared defaults still present.

### 4. Preserve continuous build deduplication separately

**Choice:** Continue managing `nix.settings.auto-optimise-store` through the existing `autoOptimise` setting.

**Rationale:** Scheduled store optimization and Nix daemon build-time optimization are separate mechanisms. The fast optimizer replaces scheduled `nix-store --optimise`, not the daemon setting.

### 5. Port tag-specific retention overrides

**Choice:** Update tags that force stock `nix.gc` retention or schedule to set equivalent `services.fast-nix-gc` values as well.

**Rationale:** Once the stock timer is disabled, tag-specific retention intent must remain effective for small boot partitions and cloud-hypervisor guests.

## Risks / Trade-offs

- The fast collector is an additional flake input and Rust package build.
- The upstream module currently handles NixOS and nix-darwin separately; this change only wires NixOS because the current service instance targets `tags.nixos`.
- Tags that set raw `nix.gc.options` cannot be automatically parsed into fast options; known tags are migrated explicitly.
