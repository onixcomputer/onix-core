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
| Cross-kernel control | Compare chunked and decodeL at identical deterministic `G=1,L=1` inside one process | A decode pass with chunked failure localizes the defect to chunked reader/compute; matching failures implicate a shared host/writer/oracle boundary or shared primitive | Exact `test all 1 1` vector | Simpler | One separately authorized process | measured |
| Data-movement round trip | Copy deterministic input and state through the custom readers and writer without WKV arithmetic | Directly tests tilized upload, state sub-page gather, output transpose, and scatter | Future minimal round-trip probe | Simpler if both paths fail | Implement under a new change before any further hardware | selected |
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

Install checks execute the production preflight and the template's diagnostic branch against a fake target. The complete vector passes; dropped or duplicated modes, dropped or duplicated selectors, reordered fields, changed selector/group/length, and appended suffix fixtures fail. Missing or wrong device selection and every reviewed unsafe cache, log, or Inspector class fail before target execution. ShellCheck, Bash syntax, tree formatting, `git diff --check`, Cairn validation and gates, architecture check `/nix/store/gd9vxrlmf8i2lqpz9x13czypijcmhbj0-ttwkv7-architecture-check`, and host closure `/nix/store/lwvg5j19fwv4wdnzqbrb3gsg7ychyfb5-nixos-system-britton-desktop-26.11.20260629.7a1a647` pass without hardware. After fast-forwarding the exact implementation into the primary checkout, pre-commit passes deadnix, statix, and treefmt while preserving unrelated user changes.

Adversarial review found that argument-only fake execution does not prove the inner environment. Exact generated-wrapper checks now independently require the pinned `TT_METAL_HOME`, pinned `TT_METAL_RUNTIME_ROOT`, and mesh-descriptor removal for the primary, probe, and diagnostic runtimes. The review also strengthened production dispatch to require exactly one `exec` line and bound device visibility inside the diagnostic wrapper rather than relying solely on a future runbook.

## Physical Outcome and Next Discriminator

The single authorized process opened physical device 1 and emitted exactly one complete record per kernel:

- `chunked 1 1`: `pcc_out=0.565670`, `pcc_state=0.512575`, `nmse_out=1.00e+00`, `nmse_state=9.87e-01`, `FAIL`;
- `decodeL 1 1`: `pcc_out=0.565647`, `pcc_state=0.512599`, `nmse_out=1.00e+00`, `nmse_state=9.89e-01`, `FAIL`; and
- aggregate: `# RESULT: 0 pass, 2 fail, 0 skip`, process status `1`.

The terminal classification is `shared-boundary-suspected`. The near-identical failure from distinct reader/compute implementations shifts priority away from a chunked-only defect, but it does not identify or prove any one shared cause. Shared candidates include host input generation, initial-state upload, data layout, the writer, host extraction, the CPU comparator, and common transpose/matmul behavior. The successful 14-case constant-tile probe continues to exclude only the reviewed constant generators and its minimal writer path.

The smallest next discriminator is a no-WKV data-movement round trip, not a primitive or stage-snapshot probe. It should copy uniquely tagged input tiles and initial-state pages through the reviewed reader/writer layouts, then check exact host-side tile placement, transpose, gather, and scatter. Positive fixtures must preserve unique tags exactly; negative host fixtures must reject row/column transposition, page permutation, duplicate/drop, and wrong scatter placement. Only if that round trip passes should a finite transpose/matmul primitive suite become active. A single advisory review was excluded because it incorrectly claimed a primitive microprobe had already run.

Raw evidence is retained at `/var/tmp/ttwkv7-cross-kernel-20260716T194725Z`; `diagnostic.log` hashes to `blake3-PlzQvFDZXFDyIWfa3Q6jFK4fHGWlf+hI/cloKaeX7iI=`. Invocation, service-stop, and rollback-arm counters are each `1`, so the runbook and authorization are exhausted. Restoration, restored health, and rollback disarm statuses are `0`; the owner is active/running with `Result=success`, `NRestarts=0`, HTTP `200`; the rollback units are absent; Inspector port `43133` is free; both board heartbeats advance with healthy DRAM, no uncorrectable GDDR errors, and no thermal trips.

Non-fatal warnings remain narrow to this exact run: power-state changes returned `Invalid argument`, firmware selected compatible single-erisc fallback, the motherboard was absent from the runtime mapping table, optional fabric exports targeted a read-only store path, shared-memory statistics creation was denied, and pinned deprecated compute APIs warned during JIT compilation. These warnings did not prevent two complete records or clean device shutdown and do not explain the common numerical mismatch by themselves.

## Validation and Authorization Boundary

Baseline package and dual-architecture checks pass at commit `43e63661`. Implementation validation is device-free: package install checks, hostile environment tests, Blackhole/Wormhole kernel compilation, full host closure, ShellCheck, formatting, pre-commit, and Cairn gates.

No physical process is authorized by “continue working on this.” A future run requires an explicit instruction authorizing exactly one device-1 cross-kernel diagnostic process after review of the committed package and one-shot. The run must retain independent timer restoration, invocation count zero before isolation, a single count transition immediately before `wkv7-diagnose diagnose`, and no retry or alternate command.

On 2026-07-16 the user supplied the exact authorization `Authorize exactly one device-1 cross-kernel diagnostic process.` The executable `run-one-shot.sh` binds that authorization to package `/nix/store/kgm3azhdgva0bwrkvil2q35l7w132l7j-ttwkv7-unstable-2026-06-22`, device 1, vector `test all 1 1`, evidence root `/var/tmp/ttwkv7-cross-kernel-20260716T194725Z`, Inspector `127.0.0.1:43133`, one invocation-count transition, exit-trap restoration, and a root-systemd rollback timer. This authorization is consumed by the first launch attempt regardless of initialization or diagnostic outcome and permits no retry, direct-runtime invocation, alternate command, or fallback probe.

The prepared evidence root is mode `0700`; its cache and log directories are writable and its fingerprint-pinned loopback `known_hosts` matches `SHA256:0vd1vzTWrAONyquNKjwnsGY7a5bY2NJlvFamtxy/akY`. Exact-system, package, kernel, runtime-state, production-dispatch, root-SSH, owner-control, HTTP `200`, and free-port checks pass. A disposable root-systemd timer rehearsed the same delayed owner-start command, was disarmed before triggering, and disappeared without changing the active/running owner or its `NRestarts=0`. Invocation, service-stop, and rollback-arm counters remain zero. No ttWKV7 device process or owner isolation occurred during preparation.

## Search Budget

Use the pinned sources and retained evidence as primary authority, the official Tenstorrent tools pages as secondary authority, at most one advisory model review, five materially distinct mechanism families, one offline implementation round, and no hardware without new explicit authorization. Stop at validated offline readiness, an exact implementation blocker, or the authorization boundary.
