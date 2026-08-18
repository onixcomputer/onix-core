## Context

Uncached evaluation of the focused ttWKV7 package takes about 1.09 seconds and its package check about 3.29 seconds, while the full `britton-desktop` toplevel takes about 18.16 seconds and 3.21 GiB of evaluator memory. The package itself is one derivation, so a wrapper or runtime-kernel edit invalidates host C++ compilation. `inventory/tags/tenstorrent.nix` is a 731-line host module that mixes package overrides, KMD and hugepage policy, package checks, deployment wiring, and a long operator guide. The active workstation and diagnostic package share one Nix store, so an exact built output does not require profile activation before a bounded manual diagnostic.

## Decisions

### Decision: Keep one repository and establish a focused package lane

**Choice:** Keep the Onix host module and ttWKV7 package in `onix-core`. Build and validate exact package outputs independently, then run the full machine closure only as the final integration gate.

**Rationale:** A nested flake or sibling repository would optimize an already-fast focused evaluation while adding lock synchronization and cross-repository pin drift. The measured expensive boundary is full-host evaluation/activation and monolithic derivation invalidation.

### Decision: Split immutable package responsibilities

**Choice:** Derive pinned upstream source once, compile host executables without local runtime-kernel edits, package patched JIT kernels separately, and compose them through a lightweight runtime derivation.

**Rationale:** The host executables refer to runtime kernel paths by string and do not embed kernel contents. Separating the derivations lets kernel and wrapper changes reuse unchanged host binaries while the final output still contains one immutable, store-addressed runtime tree.

### Decision: Fail before device initialization without explicit runtime state

**Choice:** The packaged probe wrapper permits no-device self-tests directly, but `probe` mode requires absolute writable `TT_METAL_CACHE` and `TT_METAL_LOGS_PATH` directories plus an explicit loopback `TT_METAL_INSPECTOR_RPC_SERVER_ADDRESS`. A no-device preflight validates and prepares those paths.

**Rationale:** This prevents Metalium from falling back to the package working directory or colliding with an existing Inspector endpoint. It does not select a device, stop a service, retry, or imply hardware authorization.

### Decision: Preserve tag discovery through a shim

**Choice:** Keep `inventory/tags/tenstorrent.nix` as the registry-visible module and move implementation into `inventory/tags/tenstorrent/`, separating package construction from host orchestration while retaining the generated guide beside the host policy it documents.

**Rationale:** Onix tag discovery enumerates top-level `.nix` files. A shim preserves that contract while reducing review scope and making package-only edits independent of the long generated guide.

### Decision: Make architecture compilation reproducible and device-free

**Choice:** Add a Nix check that compiles the chunked, decode, and constant-probe math kernels with the pinned Metalium SFPI compiler and architecture include/define sets for both Blackhole and Wormhole.

**Rationale:** Source grep catches lifecycle shape but not architecture-specific compile breakage. The offline check must not enumerate, open, reset, or communicate with hardware.

## Risks / Trade-offs

- A split derivation can accidentally omit an installed kernel or binary; positive and negative layout checks cover the composed output.
- The manual math-kernel compile fixture is narrower than a full Metalium JIT build and does not establish numerical correctness or runtime compatibility.
- Exact store-path execution bypasses profile activation, not Nix immutability; operators must retain the reviewed output as a GC root until evidence capture completes.
- Requiring explicit runtime paths changes probe-mode invocation and intentionally fails older unsafe commands before device creation.
- No physical result is produced by this change; another device run still requires a separately reviewed change and explicit authorization.

## Search Budget

Primary authority is the pinned ttWKV7 and TT-Metalium source plus current Onix module behavior. Validation is bounded to no-device builds, package checks, architecture compilation, host evaluation, and formatting. Hardware access is excluded.
