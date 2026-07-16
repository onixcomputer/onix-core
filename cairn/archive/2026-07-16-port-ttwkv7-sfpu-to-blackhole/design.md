# Design: Architecture-selected SFPU lifecycle for ttWKV7

## Goal and evidence contract

The goal is to make the pinned ttWKV7 chunked kernel execute correctly on one Blackhole P150 while preserving Wormhole behavior. Completion requires all of the following:

1. the package contains a reviewable fixed-input patch;
2. focused package and host-closure checks pass;
3. the deployed kernel reaches device execution on one isolated P150;
4. ttWKV7's CPU-oracle comparison passes; and
5. the owner service and both boards are healthy after the single test attempt.

Compilation alone, device creation alone, an unchecked numerical result, an automatic retry, or a test that leaves the owner service stopped are false completion.

## Pinned Metalium authority

The pinned LLK defines `_llk_math_eltwise_sfpu_start_` and `_llk_math_eltwise_sfpu_done_` for each architecture. Wormhole's start helper selects address-modifier slots 4 through 7 and its finish helper clears that selection. Blackhole's start helper omits the unsupported selection and its finish helper performs the Blackhole-required destination cleanup. The ttWKV7 source manually duplicates the Wormhole sequence instead of using those architecture-selected helpers.

## Approach registry

| Family | Mechanism | State | Evidence or blocker |
|---|---|---|---|
| `portable-llk-helper` | Replace the custom SFPU prologue and epilogue with Metalium's architecture-selected helper pair. | selected | The pinned Wormhole and Blackhole helper bodies exactly encode their distinct setup and cleanup sequences. |
| `blackhole-conditional` | Keep the copied sequence and conditionally omit only `set_addr_mod_base()` on `ARCH_BLACKHOLE`. | rejected | This duplicates LLK policy and can drift when architecture-specific cleanup changes. |
| `direct-addrmod-programming` | Recreate the address-modifier setup with Blackhole `addr_mod_t`. | rejected | The constant generator does not require a new address-modifier policy; Metalium already owns this lifecycle. |

## Implementation

A fixed patch changes only `wkv7_chunked_compute.cpp`:

- `_llk_math_eltwise_sfpu_start_(0)` opens the SFPU operation;
- the existing 32-iteration constant generator remains unchanged; and
- `_llk_math_eltwise_sfpu_done_()` closes it.

The package install check requires both helper calls and rejects `math::set_addr_mod_base()` in the installed kernel source. This gives positive and negative regression coverage without claiming that a Nix build compiles JIT kernels for a physical architecture.

Before deployment, the captured failing Blackhole `trisc1` compiler command is replayed offline against the patched package and its original generated descriptors. Producing the expected object file establishes that the helper symbols resolve under `ARCH_BLACKHOLE` without opening a device; it does not establish runtime or numerical correctness.

## Adversarial audit

Review must verify that the helper pair is available through the pinned compute API includes, that the destination index remains zero, that the loop and generated values are unchanged, and that the finish helper is paired exactly once with the start helper. The hardware test must use a fresh evidence directory, preserve the inherited P150x2 descriptor only as a caller-side regression input, verify that the wrapper removes it, and make no retry.

## Hardware safety

Physical device 1 is owned by `docker-tt-inference-server-llama-3-1-8b-instruct-p150.service`. Capture service and TT-SMI state, stop only that unit, perform one bounded `TT_VISIBLE_DEVICES=1 wkv7 test chunked 1 1` invocation, then restore the prior active state through a trap. Device 0's VibeThinker service remains untouched.

## Measured outcome

Commit `eaa6d263` was deployed as generation `/nix/store/qhlp0ghkcqpdvvrnipqwipw3qa141aid-nixos-system-britton-desktop-26.11.20260629.7a1a647` with package `/nix/store/mdw5x4vgmq1nnnl9zd7nhyfxmydzcn9c-ttwkv7-unstable-2026-06-22`. The single device-1 test JIT-compiled all 21 kernel artifacts and executed the chunked WKV path, proving that the architecture-selected helper port crosses the prior compiler boundary.

The CPU oracle rejected the numerical result: `pcc_out=0.565670`, `pcc_state=0.512575`, `nmse_out=1.00e+00`, and `nmse_state=9.87e-01`, against the upstream tolerance of `6e-02`. The process returned status 1. This disproves P150 numerical compatibility for the tested package and shape; the helper port does not establish broader Blackhole correctness.

No retry was made. The owner service recovered with a passing health endpoint, `Result=success`, and `NRestarts=0`. Both boards retained healthy DRAM, zero uncorrected GDDR errors, zero thermal trips, and advancing heartbeats. Evidence is retained at `/var/tmp/ttwkv7-smoke-blackhole-sfpu-20260716T105341Z`.

## Search budget

Use the pinned Metalium source as primary authority, the pinned ttWKV7 source as the implementation artifact, at most two advisory model reviews, and one post-deployment hardware execution. The budget terminated after that one execution reached WKV and produced a deterministic numerical failure; further Blackhole semantic work requires a separately reviewed test authorization.
