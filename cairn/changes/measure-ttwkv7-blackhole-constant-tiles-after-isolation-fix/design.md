## Context

The exact package remains `/nix/store/plr5vlpv1q5g4zl6c2q065bwsmbhxkrr-ttwkv7-unstable-2026-06-22`, with immutable kernels at `/nix/store/8m898sjjhcvva2l8375r1wi5alp6cmj3-ttwkv7-kernels-unstable-2026-06-22/share/ttwkv7/kernels`. The activated owner-control helper is `/nix/store/6m9zwmdfc1vyrxw2znbl39s78bz73ycp-ttwkv7-owner-control/bin/ttwkv7-owner-control`, and both the active system and system profile are `/nix/store/vb9zjhp20rpg7g1g4ypmmcsq7n4s9d3p-nixos-system-britton-desktop-26.11.20260629.7a1a647`.

The prior measurement retained invocation count zero because isolation failed before service mutation. This change is a new authorization boundary and must not rerun the archived script.

## Success Contract

Success requires fourteen lines with `mismatches=0 PASS`—seven generated patterns at lengths 1 and 32—plus `constant-tile device probe: PASS` from one process invocation. Passing preflight, initialization, JIT, a subset, approximate values, service recovery, or process status alone is not success.

Allowed terminal outcomes are `validated`, `mask-mismatch`, `initialization-blocked`, `timed-out`, or `isolation-blocked`. Every terminal outcome exhausts this change's physical budget only if invocation count reached one; no outcome authorizes a retry.

## Authorization Boundary

The user's exact instruction `Authorize one device-1 constant-tile probe.` authorizes one timeout-wrapped invocation of the reviewed package's `probe` mode after all offline and runtime preconditions pass. It does not authorize a second process invocation, full-WKV execution, source mutation, deployment, another physical device, or fallback command.

The invocation is bound to device 1, owner unit `docker-tt-inference-server-llama-3-1-8b-instruct-p150.service`, evidence root `/var/tmp/ttwkv7-constant-probe-20260716T171944Z`, Inspector address `127.0.0.1:43128`, and a 180-second timeout with a 10-second termination grace.

## Decisions

### Execute exact store outputs

The one-shot invokes the active immutable package, kernel, and owner-control outputs directly. No activation or rebuild is part of the physical boundary.

### Arm independent restoration before isolation

Before owner stop, strict fingerprint-pinned loopback root SSH creates a transient root-systemd timer that starts only the exact owner unit after 240 seconds. The ordinary exit trap invokes `ttwkv7-owner-control restore`; it disarms the timer only after owner and endpoint health recover. If orchestration is killed, the system timer survives and performs the bounded start.

### Count at the process boundary

The retained count changes from zero to one immediately before the sole timeout-wrapped `probe` command. Initialization failures, signals, and timeout consume authorization exactly like numerical output.

### Preserve raw evidence

The runbook stores process status and raw log without interpretation. Classification occurs afterward from the invocation count, process status, exact fourteen comparison lines, and final marker.

## Approach Registry

| Family | Mechanism | Claim | Evidence | State |
|---|---|---|---|---|
| Helper-only restoration | EXIT trap calls the exact start grant | Ordinary shell exits restore the owner | Activated helper validation passes | active but insufficient for SIGKILL |
| User-systemd rollback | User timer calls the helper | Survives orchestration exit | User manager runs but `Linger=no` | blocked |
| Root-systemd rollback | Strict loopback root SSH arms a fixed transient timer | Survives client and user-manager loss | Root channel fingerprint and identity were validated; exact command is reviewable | selected |
| Mask correctness | Reset-aware SFPU finalization emits exact tiles | All fourteen comparisons pass | Dual-architecture compilation passes; hardware values remain unknown | independent |
| Lane mapping | Blackhole destination lanes permute elements | Mismatch geometry identifies mapping failure | No tile output exists yet | independent |
| Tolerance | Relax comparison | Hide exact zero/one errors | Forbidden by success contract | falsified |

## Adversarial Audit

False completion includes zero invocation, a passing subset, status zero without fourteen lines, plausible values, timer restoration alone, or initialization without comparison. The run must reject wrong metadata, a busy Inspector port, unavailable exact grants, unhealthy owner state, failed rollback arming, active post-isolation ownership, or nonzero prior invocation count before probe mode. The script contains one literal `probe` execution and no retry loop.

Root SSH is used only to prove the channel, arm/show/stop the named rollback timer, and inspect its state. Owner stop, ownership proof, and ordinary restoration remain inside the reviewed least-privilege helper. Hardware evidence is limited to tt-smi snapshots and the single probe process.

## Search Budget

Primary authority is the pinned package, active NixOS closure, systemd, retained evidence, and raw probe output. Offline review is bounded to package, architecture, shell, lifecycle, metadata, and no-device checks. Physical search is bounded to one process invocation, one selected device, and one 180-second timeout. Validated or any exact blocker terminates the search.
