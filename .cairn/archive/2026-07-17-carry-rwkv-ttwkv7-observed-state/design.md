## Context

The archived observed-layer boundary locks exact device-1 output and post-state artifacts from the sole authorized workload. Its replay proves complete same-token composition through layer zero, while the enclosing session remains immutably `unsafe`. The next unresolved structural question is whether the physical matrix post-state has the expected orientation and semantics when consumed by another recurrent step.

This change is device-free. It reuses package-owned immutable evidence, performs no owner-service transition, opens no Tenstorrent device, and creates no hardware authorization.

## Goals / Non-Goals

**Goals:**

- Preserve the accepted observed-layer receipt byte-for-byte.
- Build the next layer-zero token from token ID `2`, the accepted greedy continuation after prefix `[1, 2]`.
- Carry exact physical matrix state plus observed-composition host attention/channel state into one additional recurrent step.
- Apply the same BF16 encode/decode transport boundary to the next-step WKV inputs, pre-state, raw output, and post-state.
- Lock complete-vector identities, deviations, and reset/transposed-state discriminators in a separate deterministic receipt.
- Keep recurrence and suffix logic in pure functions with a fixed `--evidence-root PATH` imperative shell.

**Non-Goals:**

- Running another physical workload or reusing either exhausted authorization.
- Claiming that the third-token WKV operation ran on hardware.
- Claiming a wholly device-executed layer, all-layer carry, generation, serving, throughput, latency, or broad P150 compatibility.
- Changing the immutable `unsafe` session classification.

## Portfolio decision

Four implementation families were considered:

1. Treat same-token composition as sufficient. This is cheapest but leaves state orientation and retained-state use untested.
2. Add one explicit CPU continuation seeded by exact physical post-state. This isolates the recurrent carry question with existing evidence and no hardware risk.
3. Build all twelve layers immediately around a simulated WKV backend. This advances farther but correlates many new mechanisms before the first carry boundary is closed.
4. Add Rust/C++ FFI and a persistent Metalium process now. This is closest to runtime execution but is a much larger shell and cannot be physically validated without new authorization.

Family 2 is selected. It is the smallest independent discriminator before all-layer orchestration. Families 3 and 4 remain later rungs.

## Decisions

### Decision: preserve the prior receipt as an independent regression authority

The new harness invokes the accepted observed replay and fingerprints its canonical receipt, but emits a separate schema and output. Existing same-token evidence does not gain mutable fields.

### Decision: model host state and matrix state separately

The carry seed consists of:

- attention previous-input state from layer zero's second token,
- channel-mix previous-input state from each second-token composition path, and
- matrix state from source FP32, expected BF16, or exact physical post-state.

This mirrors the runtime ownership boundary and prevents the physical matrix artifact from being mistaken for complete layer state.

### Decision: quantize only the ttWKV7 transport boundary

The expected and observed continuation paths quantize next-step WKV inputs and pre-state to BF16 before recurrence, then quantize raw WKV output and post-state before the shared CPU suffix. Host normalization, projections, residuals, and channel mix remain FP32. The source path remains the accepted all-FP32 equation.

### Decision: require reset-state and transposed-state negative controls

A reset control reuses the observed host state and next-step WKV inputs but replaces the physical matrix state with zero state. A second control transposes every physical per-head matrix while preserving the same host state and inputs. The observed and reset complete outputs and post-states must differ by named, non-zero floors, and the observed continuation must remain closer to the expected continuation than to the transposed control. Together these controls demonstrate retained-state sensitivity and orientation without claiming physical next-step execution.

### Decision: fail closed on evidence and invocation drift

The new shell accepts only the exact `--evidence-root PATH` vector. Existing exact evidence validation remains authoritative. Nix checks mutate the physical post-state and classification, and they reject missing, extra, or reordered invocation arguments. The new core also locks the canonical prior observed receipt identity.

## Risks / Trade-offs

- One CPU continuation cannot establish hardware behavior for that continuation; the receipt labels the WKV executor as CPU with BF16 transport emulation.
- Expected and observed paths may be extremely close, so exact fingerprints and complete-vector deviations are retained rather than relying on rankings.
- Reusing shared CPU equations can share equation defects; the accepted framework parity and prior complete-vector boundary remain independent controls.

## Validation plan

- Run the current observed-layer and framework checks before core mutation.
- Build and run the new fixed-invocation continuation twice and require byte-identical receipts.
- Require accepted observed-layer receipt identity to remain unchanged.
- Require finite complete-vector comparisons and reset-state divergence.
- Reject malformed evidence and unexpected arguments.
- Rebuild historical layer, token, stateful decode, text, prompt, BF16 boundary, host-layout, decode-reader, architecture, and boundary-device checks.
- Prove the ordinary runtime closure remains free of the hardware fixture and Python/PyTorch.
- Run focused formatting and clean Cairn validation/gates, then sync and archive with deterministic receipts.

## Validation evidence

The accepted same-token observed-layer receipt remains byte-identical at 7,813 bytes with BLAKE3 `0f2e08a9966672ab8d076ec2a601e336c0e0022ea4af023e472a7bbc05ba6d18`. The new state-carry receipt is 23,965 bytes with BLAKE3 `58e433a04a10319293b18d6003659b53a04a95e9cf9cc7b540c2448c98ed6a33`; repeated fixed-invocation runs are byte-identical. The shared library, observed-state core, and imperative shell have BLAKE3 identities `6d2e9039291e1600b3b350458e5c3af1fb34ebc79775672c94eee4ec870a54db`, `3c658d2af4c1acda70bdcb92e18a8effd4c96fa08b0d2680fb6c81d6bac8b386`, and `e503f39aa2f7a1bd03536aa9d08316c00536372792c4e76c3a8d1b2c3ce36199`.

For token sequence `[1, 2, 2]`, the exact physical seed state fingerprint is `f8c894bac89637de0885f6fb351b7b21dbfcaa7a6f665d22fd0d27838de0257c`. The CPU continuation from that state yields raw-output, post-state, and final-layer fingerprints `cc9b373258d7a49b44e1ab3d2f2d06853b549f8b72acc0f007a4d591005921e5`, `e6069234ca935f70dcc8278876fb15cbacc0e374b52e6f33efa5482b5daba7bc`, and `67a0a53d12921095d47995f4a4845543c8e00e569e6f94c1b43fc5a451a2b39d`. Its maximum absolute deviations versus the expected BF16 continuation are `0.00024414062` for raw WKV output, `0.0078125` for post-state, and `0.00032252073` for complete layer output. Its complete output differs from the source-FP32 continuation by `0.00083230436`.

The zero-state control differs from the observed continuation by `1.1815033` in post-state and `1.3526523` in complete layer output. The independently transposed per-head matrix control differs by `1.2164612` and `1.3400576`, respectively. The observed continuation is therefore far closer to the expected BF16 continuation than to either control, closing this device-free retained-state orientation boundary without claiming that the third WKV step ran on hardware.

Clean detached-worktree outputs are `/nix/store/3sq1xbw3c1r0li2756q52ra10k3vh71h-rwkv-layer-harness-0.1.0`, `/nix/store/i7ww7mi8p76gz4w2gkxwgg8hp1xv5qrn-rwkv-ttwkv7-observed-state-carry`, `/nix/store/0rjsayjxfiylv05hn8vkrx8nkwk4w8qb-rwkv-ttwkv7-observed-layer-replay`, `/nix/store/p9wp351q6nllzizbsihxh3ki6v33f8ni-rwkv-layer-harness-torch-equation-parity`, `/nix/store/2qzgmx9s37236240xzzwcgvq1wr8mq30-rwkv-ttwkv7-boundary-device-check`, `/nix/store/a35lxicn52mab4iswjxj3wrhcq4iyvfh-rwkv-ttwkv7-host-layout-check`, `/nix/store/nl8v9n39hhmvrmya2lx2214k7hsbnkwx-rwkv-ttwkv7-decode-reader-check`, and `/nix/store/b85dmwmfg7zjlszfihpa9bwxg9k04srz-ttwkv7-architecture-check`. The runtime closure contains fifteen paths and no Python/PyTorch. The mechanically rebuilt, still-`not_run` boundary package is `/nix/store/cakn4ql3kky00yjvzfbn0gksyfh3sf2n-rwkv-ttwkv7-boundary-device-0.2.0`, with plan/not-run BLAKE3 identities `d288da56d5d10fbf32b9ccbf8abd08133c1778b74b63848b58754f1737c9a3ac` and `79a229599cd82c732f2cfaca629530c363354737a90c4f7f7456d5da16c6adc0`; no runbook or device process was invoked.

Positive replay, exact prior-receipt preservation, repeated determinism, classification/state mutation rejection, missing/extra/reordered invocation rejection, reset and transposed-state controls, source uniqueness checks, historical package receipts, framework parity, host layout, decode-reader, architecture, boundary-device compatibility, formatting, and the archived runbook checker/self-test pass. Clippy remains unavailable because the repository dev shell requires missing `/run/secrets/vars/nix-signing-key/key`, while direct host Cargo is absent; Rust compilation, unit tests, install checks, and the relevant Nix checks pass. Cairn sync accepted the requirement with receipt `493473bde653e6cc5c6baf32e3ba923480b8a505a5b036f5511dd7d059c85688`; archive execution produced receipt `9432fc16ad78234c248c0b66ac53a36672af2f487eb53e85a3438714c6c8bbe3`. Clean post-archive validation reports `changes: 0`, `valid: true`, and no issues or substance issues.
