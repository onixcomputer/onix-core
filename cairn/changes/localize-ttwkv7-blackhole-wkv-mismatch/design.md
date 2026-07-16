# Design: Localize the ttWKV7 Blackhole numerical mismatch

## Context

The pinned package's chunked `G=1,L=1` process reached device execution and returned `pcc_out=0.565670`, `pcc_state=0.512575`, `nmse_out=1.00e+00`, and `nmse_state=9.87e-01`. A later exact probe proved all seven generated constant patterns at lengths 1 and 32 on the selected P150. The next check therefore targets data movement and WKV arithmetic rather than SFPU constant generation.

For `L=1`, the recurrence simplifies enough to make the cross-kernel comparison especially discriminating: strict-causal Gram matrices vanish, the triangular inverse is identity, and the expected result reduces to direct state-decay and rank-one updates. The pinned executable can run both implementations through `test all 1 1` while reusing one device for the process.

## Success Contract

The offline implementation succeeds when the production diagnostic wrapper:

1. requires `TT_VISIBLE_DEVICES=1` exactly and rejects missing, relative, store-owned, unwritable, or non-loopback runtime state before target execution;
2. accepts only one diagnostic mode with no suffix arguments;
3. executes the exact immutable runtime vector `test`, `all`, `1`, `1` once and in order;
4. proves dropped, duplicated, reordered, or caller-appended arguments fail deterministic package checks; and
5. leaves the existing constant probe and primary command behavior unchanged.

A later physical comparison is not authorized by this change's implementation work. If separately authorized, valid evidence requires one device-owning process, exactly one chunked result, exactly one decodeL result, the final aggregate result, raw process status, and healthy owner restoration. Compilation, one result line, inferred metrics, model agreement, a relaxed tolerance, or a second invocation are false completion.

Allowed terminal classifications are `chunked-path-localized`, `decode-path-localized`, `shared-boundary-suspected`, `prior-failure-not-reproduced`, `partial-diagnostic`, `initialization-blocked`, `timed-out`, `isolation-blocked`, or `orchestration-blocked`. Every physical classification is narrow and terminal for its one-process authorization.

## Functional Core and Imperative Shell

The wrapper's pure predicates classify paths, Inspector addresses, modes, and argument counts without device access. Its imperative shell creates validated directories and performs one final `exec` into the immutable runtime. Package tests substitute a fake target and compare complete newline-delimited argument vectors; no fake or production package check may enumerate or initialize a Tenstorrent device.

The pinned C++ executable remains the source of deterministic inputs and CPU-oracle metrics. This change does not duplicate WKV arithmetic or alter kernel tolerances before the cross-kernel discriminator is measured.

## Approach Registry

| Family | Mechanism | Claim | Concrete artifact | Gap | Next check | State |
|---|---|---|---|---|---|---|
| Cross-kernel control | Compare chunked and decodeL at identical deterministic `G=1,L=1` inside one process | A decode pass with chunked failure localizes the defect to chunked reader/compute; matching failures implicate a shared host/writer/oracle boundary or shared primitive | Exact `test all 1 1` vector | Simpler | One separately authorized process | active |
| Data-movement round trip | Copy deterministic input and state through the custom readers and writer without WKV arithmetic | Directly tests tilized upload, state sub-page gather, output transpose, and scatter | Future minimal round-trip probe | Simpler if both paths fail | Implement only after cross-kernel evidence | independent |
| Primitive microprobe | Compare transpose, matmul accumulation, log/exp/recip, and row/column broadcasts against host oracles | Isolates Blackhole primitive/configuration behavior | Future finite primitive suite | Simpler if failures correlate by primitive | Implement only after cross-kernel evidence | independent |
| Stage snapshots | Export omega, normalized streams, Gram matrices, inverse, SA, output terms, and final-state terms | Finds the first divergent full-kernel intermediate | Future dedicated diagnostic CB and writer | More invasive | Use after smaller discriminators | blocked |
| Runtime debug tools | DPRINT TileSlice, Watcher, Inspector, or synchronized checkpoints inspect CB state and kernel progress | Provides device-side evidence for a surviving stage hypothesis | Official Tenstorrent tools documentation and pinned source | Tools are fully supported only on source builds; checkpoints require every active RISC and can hang | Escalate only for a bounded unresolved stage | audit |
| Tolerance | Raise the NMSE threshold | Would hide the mismatch instead of explaining it | Existing near-one NMSE | Weaker than goal | None | falsified |

## Tenstorrent Debugging Research

Primary implementation authority is pinned ttWKV7 revision `84d8b6a44729cc358f163e7ab9614b0a1b8ddc09` and pinned TT-Metalium 0.74 source. Official Tenstorrent documentation says:

- Device Debug Print can emit formatted scalars and circular-buffer `TileSlice` values, but every line must end in a newline and debug tools are only fully supported on source builds.
- Watcher detects NOC and active-CB out-of-bounds transactions and reports waypoints, making it appropriate for hangs or transfer corruption rather than the first numerical discriminator.
- Inspector records host-runtime state and persists no-argument data under `generated/inspector`; it does not replace tensor comparison.
- Debug checkpoints synchronize every active RISC on participating cores; omission by any active RISC hangs the barrier, so they are disproportionate before the existing two-kernel control is measured.

These sources justify retaining writable runtime paths and Watcher/Inspector evidence while deferring DPRINT and checkpoint instrumentation.

## Adversarial Audit

The two paths do not have wholly independent implementations: they share host input generation, initial-state upload, output allocation, the writer, host extraction, and CPU oracle. They use different readers and compute kernels. Therefore matching failures do not prove a single shared component, and a decode pass does not prove every chunked primitive is defective. The classifier must report only the strongest mechanism family supported by exact result lines.

The wrapper must not accept a caller-selected kernel, shape, target, or tolerance. Package tests must compare complete vectors rather than grep for target text. A process that initializes the device but emits only one result is partial, not permission to invoke again. Debug environment changes, alternate commands, direct runtime execution, or fallback probes require a new reviewed boundary.

## Offline Implementation Evidence

Package `/nix/store/kgm3azhdgva0bwrkvil2q35l7w132l7j-ttwkv7-unstable-2026-06-22` contains one production diagnostic `exec` line targeting its immutable runtime with exactly `test all 1 1`. The wrapper requires `TT_VISIBLE_DEVICES=1`, rejects suffixes and invalid modes, and passes only validated writable cache/log paths plus a loopback Inspector address. Its inner runtime pins both Metalium roots, clears the mesh descriptor, and enters the immutable kernel directory.

Install checks execute the production preflight and the template's diagnostic branch against a fake target. The complete vector passes; dropped or duplicated modes, dropped or duplicated selectors, reordered fields, changed selector/group/length, and appended suffix fixtures fail. Missing or wrong device selection and every reviewed unsafe cache, log, or Inspector class fail before target execution. ShellCheck, Bash syntax, tree formatting, `git diff --check`, Cairn validation and gates, architecture check `/nix/store/gd9vxrlmf8i2lqpz9x13czypijcmhbj0-ttwkv7-architecture-check`, and host closure `/nix/store/lwvg5j19fwv4wdnzqbrb3gsg7ychyfb5-nixos-system-britton-desktop-26.11.20260629.7a1a647` pass without hardware.

Adversarial review found that argument-only fake execution does not prove the inner environment. Exact generated-wrapper checks now independently require the pinned `TT_METAL_HOME`, pinned `TT_METAL_RUNTIME_ROOT`, and mesh-descriptor removal for the primary, probe, and diagnostic runtimes. The review also strengthened production dispatch to require exactly one `exec` line and bound device visibility inside the diagnostic wrapper rather than relying solely on a future runbook.

## Validation and Authorization Boundary

Baseline package and dual-architecture checks pass at commit `43e63661`. Implementation validation is device-free: package install checks, hostile environment tests, Blackhole/Wormhole kernel compilation, full host closure, ShellCheck, formatting, pre-commit, and Cairn gates.

No physical process is authorized by “continue working on this.” A future run requires an explicit instruction authorizing exactly one device-1 cross-kernel diagnostic process after review of the committed package and one-shot. The run must retain independent timer restoration, invocation count zero before isolation, a single count transition immediately before `wkv7-diagnose diagnose`, and no retry or alternate command.

## Search Budget

Use the pinned sources and retained evidence as primary authority, the official Tenstorrent tools pages as secondary authority, at most one advisory model review, five materially distinct mechanism families, one offline implementation round, and no hardware without new explicit authorization. Stop at validated offline readiness, an exact implementation blocker, or the authorization boundary.
