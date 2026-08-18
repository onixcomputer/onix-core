## Context

Commit `eaa6d263` replaced the chunked constant generator's direct Wormhole address-modifier setup with `_llk_math_eltwise_sfpu_start_(0)` and `_llk_math_eltwise_sfpu_done_()`. Blackhole then compiled and executed all 21 JIT artifacts, but the single CPU-oracle run failed with `pcc_out=0.565670`, `pcc_state=0.512575`, `nmse_out=1.00e+00`, and `nmse_state=9.87e-01`.

The pinned Blackhole `_llk_math_eltwise_sfpu_done_()` only clears the destination-register address. `_llk_math_eltwise_sfpu_done_with_addrmod_reset_()` additionally performs the same SFPU wait and `TTI_SETC16(2, 0)` reset as the original ttWKV7 epilogue. The pinned Wormhole `_llk_math_eltwise_sfpu_done_()` performs its architecture-specific address-modifier cleanup. The installed decode kernel still directly calls the Wormhole-only setup primitive.

## Success Contract

The change succeeds only if package checks and offline JIT compilation prove both architecture paths compile, and one isolated P150 invocation returns every generated constant tile exactly equal to the pure CPU oracle. Compilation success, plausible output, relaxed tolerances, a passing subset of masks, or a restored service alone are false completion. The hardware invocation must not run the full WKV workload, must not retry, and must restore the device-1 owner service even on failure.

Allowed terminal outcomes are validated, blocked by an exact mask mismatch or compiler/runtime diagnostic, exhausted after the one-run budget, or user-decision-required if service isolation cannot be established safely.

## Decisions

### Decision: Preserve architecture-specific finalization

**Choice:** Use `_llk_math_eltwise_sfpu_done_with_addrmod_reset_()` when `ARCH_BLACKHOLE` is defined and `_llk_math_eltwise_sfpu_done_()` when `ARCH_WORMHOLE` is defined. Reject unsupported architecture compilation rather than guessing another lifecycle.

**Rationale:** This preserves the original Blackhole-relevant stall/C16 reset while retaining the pinned Wormhole helper's setup/cleanup pair. The source difference is the strongest current causal hypothesis, but the exact tile probe remains authoritative.

### Decision: Diagnose constants before WKV arithmetic

**Choice:** Add a separate probe executable and minimal compute/writer kernels. One device open generates all seven chunked constant patterns for lengths 1 and 32, reads them back, and compares every BF16 element exactly to a pure host oracle.

**Rationale:** Zero/one masks permit exact comparison and isolate SFPU lifecycle, destination addressing, lane coordinates, packing, and transfer from the much larger recurrence. A single process respects the device-creation safety boundary.

### Decision: Keep pure expectations separate from hardware orchestration

**Choice:** Implement pattern validation and expected-tile generation as deterministic functions exercised by `--self-test`; keep device creation, program dispatch, output, and exit handling in a thin shell.

**Rationale:** The oracle can be tested without hardware and invalid pattern/length inputs can fail deterministically.

## Approach Registry

| Family | Mechanism | Evidence | Next check | State |
|---|---|---|---|---|
| SFPU finalization | Missing Blackhole stall/C16 reset corrupts later constant generations | Pinned Blackhole helper bodies differ and upstream performed the reset | Exact seven-mask probe after architecture-specific finalization | active |
| Destination mapping | Blackhole `dst_reg[k]` or `vConstTileId` maps logical coordinates differently | Pinned docs define even tile IDs and Blackhole sources document destination stride behavior | Inspect mismatch geometry from exact probe | independent |
| WKV arithmetic/layout | Standard compute or transfer semantics differ after constants | End-to-end NMSE is near one, but no intermediate evidence exists | Consider only if every mask passes | blocked |
| Tolerance | Blackhole needs a looser numerical threshold | Exact zero/one masks and NMSE near one do not support this | None | falsified |

## Adversarial Audit

A source-level epilogue mismatch does not prove causality. The probe must reject one incorrect element, report the first mismatch and total mismatch count, and keep each pattern/length result separate. A passing mask probe establishes only constant generation for the tested package, architecture, and cases; it does not establish WKV numerical correctness, decode correctness, performance, or general P150 support.

## Risks / Trade-offs

- A probe kernel still accesses physical hardware; service ownership, a restoration trap, and one-invocation/no-retry policy remain mandatory.
- Refactoring upstream generator logic before measuring it could obscure the failure, so the probe intentionally mirrors the reviewed device predicate while the host oracle computes expected logical tiles independently.
- The two lengths increase diagnostic coverage within one device open but do not cover every partial length.
- The pre-existing SSH/SOPS host-key rotation may make normal Clan activation fail; deployment must not modify trust or secret material.

## Validation Evidence

The exact package passed its no-device oracle self-test and package install checks. Replayed math-TRISC compilation produced objects for `wkv7_chunked_compute.cpp`, `wkv7_decodeL_compute.cpp`, and `ttwkv7_constant_tile_compute.cpp` under both the pinned Blackhole and Wormhole compiler/include/define sets. The accelerator inventory and full `britton-desktop` closure also built before commit `3af9ffd2f69bfb1ba6a5ffc7a7f277cb5a823529` was activated as `/nix/store/mwndchzmrkqb2sh27qa9dj76axwwraqj-nixos-system-britton-desktop-26.11.20260629.7a1a647` with package `/nix/store/bnc9yk3wmsqdl98lsx7vamdzvdqsml9f-ttwkv7-unstable-2026-06-22`.

## Measured Outcome

Exactly one device-1 invocation ran and returned status 1. `TT_VISIBLE_DEVICES=1` mapped physical PCIe device 1 to logical device 0; the runtime ignored the inherited linked-card descriptor through the package wrapper and auto-discovered a one-chip mesh. Before any probe kernel JIT artifact or mask result was produced, default Metalium diagnostics attempted to create `generated/watcher` beneath the wrapper's read-only package working directory. Device initialization then failed closed with `filesystem error: cannot create directories: Read-only file system`. Inspector reported the same read-only working-directory boundary and a pre-existing loopback RPC-port collision. The JIT summary remained `0/8` and no constant tile was compared.

This exhausts the one-run authorization at an infrastructure boundary. It neither proves nor disproves the Blackhole finalizer hypothesis, destination-lane mapping, constant masks, WKV arithmetic, decode correctness, performance, or general P150 support. A future attempt requires a separately reviewed change that provides a writable `TT_METAL_LOGS_PATH` or equivalent runtime working path, followed by separate hardware authorization; this change must not be retried.

Evidence is retained at `/var/tmp/ttwkv7-constant-probe-20260716T133450Z`. The restoration trap restarted `docker-tt-inference-server-llama-3-1-8b-instruct-p150.service`; it recovered with `ActiveState=active`, `Result=success`, `NRestarts=0`, and HTTP 200 health. Both boards retained healthy DRAM, zero uncorrected GDDR errors, zero thermal trips, and advancing heartbeats across the two post-run snapshots.

## Search Budget

Primary authority is limited to the pinned ttWKV7 and Metalium sources. Advisory review is limited to the already-used VibeThinker pass and is non-authoritative. Validation uses focused package/machine checks, offline JIT compilation, and exactly one physical device-1 probe invocation with no retry. The budget terminated at the exact read-only diagnostics-path blocker; no additional physical execution is authorized.
