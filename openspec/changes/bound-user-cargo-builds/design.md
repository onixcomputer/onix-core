## Context

`britton-desktop` already has a managed Cargo configuration preserving `target-dir = "/home/brittonr/.cargo-target"`, `net.retry = 3`, `term.quiet = false`, a Nix-managed rustc-wrapper, sccache, and mold. That compatibility surface should remain stable while adding responsiveness controls.

## Goals / Non-Goals

**Goals:**
- Prevent direct Cargo invocations from saturating all 32 hardware threads by default.
- Preserve sccache fail-open behavior and the shared target directory unless a later migration explicitly changes it.
- Give the operator an explicit way to run large local builds under systemd resource controls.
- Make cache/target disk growth observable and bounded.

**Non-Goals:**
- Replace sccache with a distributed cache.
- Remove the shared target dir in this change.
- Force every repository to use the same Cargo profile flags.

## Decisions

### 1. Bound Cargo jobs in managed config

**Choice:** Add a managed Cargo jobs policy, such as `[build] jobs = 20` or another measured value, through the existing Home Manager-owned Cargo config.

**Rationale:** Direct Cargo builds can otherwise saturate every thread even after Nix daemon tuning. A default job limit keeps interactive builds fast without monopolizing the workstation.

**Alternative:** Rely on users to remember `-j`. Rejected because the goal is durable desktop behavior.

### 2. Keep cache compatibility first

**Choice:** Preserve the existing rustc-wrapper, mold linker, `target-dir`, `net.retry`, and `term.quiet` behavior while layering in job limits and documentation.

**Rationale:** The current config solves real cache/fallback problems; responsiveness work should not regress it.

### 3. Treat target/cache storage policy as an observable guardrail

**Choice:** Add explicit cache-size and target-dir cleanup/storage guidance before moving directories or creating datasets.

**Rationale:** `/home/brittonr/.cargo-target` and sccache can grow substantially. A policy and verification path reduce disk surprises without coupling this change to a storage migration.

## Risks / Trade-offs

**Reduced build parallelism for direct Cargo** → Document override paths and resource-scoped wrappers for intentional heavy builds.

**Cache hit regressions** → Re-run sccache stats/fail-open checks after config changes.

**Disk policy without enforcement** → At minimum, expose size checks and cache-size config; defer storage migration to a future OpenSpec if needed.
