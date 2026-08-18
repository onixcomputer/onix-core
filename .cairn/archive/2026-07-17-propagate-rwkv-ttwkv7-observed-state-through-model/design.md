## Context

The archived observed-layer replay locks the sole accepted physical layer-zero WKV output and post-state for token sequence `[1, 2]`. The archived state-carry replay proves that the exact physical matrix state has the expected retained-state sensitivity and orientation when token ID `2` is executed by the CPU equation with BF16 transport emulation. The next structural question is whether this physical boundary can participate in the existing twelve-layer recurrent model orchestration and language-model head without state, layer-order, or `v_first` drift.

This change is device-free. It consumes only the package-owned evidence, opens no Tenstorrent device, invokes no process API, changes no owner service, and creates no hardware authorization.

## Goals / Non-Goals

**Goals:**

- Preserve the accepted observed-layer and state-carry receipts byte-for-byte.
- Inject the exact physical layer-zero raw output and post-state at token position two.
- Continue that token through CPU layers 1–11 while preserving token-local `v_first` semantics.
- Execute token position three through all twelve CPU layers, with BF16 transport emulation at layer zero and FP32 host/later-layer equations.
- Compare source-FP32, expected-BF16, observed, reset, and transposed-state paths through final normalization, untied LM head, top-two ranking, and complete recurrent state.
- Lock per-layer output identities and require reset/transposed controls to remain distinguishable at model logits.
- Keep the imperative shell fixed to `--evidence-root PATH`.

**Non-Goals:**

- Running another physical workload or reusing either exhausted authorization.
- Claiming that token position three or layers 1–11 ran on Tenstorrent hardware.
- Claiming a wholly device-executed layer/model, hardware-backed generation, serving, throughput, latency, or general P150 compatibility.
- Reclassifying the immutable terminal `unsafe` session.

## Portfolio decision

Four mechanisms were considered:

1. Compose only the physical token-two layer output through layers 1–11 and emit logits. This validates layer ordering but leaves recurrent all-layer state carry untested.
2. Seed only layer zero at token three, then execute the complete token through all twelve CPU layers while retaining layers 1–11 state from the physically perturbed token-two path. This tests model-wide recurrent composition with the existing evidence.
3. Introduce a generic asynchronous WKV backend abstraction for every layer immediately. This is closer to a future persistent runtime but adds scheduling and ownership mechanisms before model composition is closed.
4. Add a persistent Metalium process and physically execute another boundary. This requires new authorization and cannot be validated in this change.

Family 2 is selected. It is the strongest device-free discriminator that reuses accepted evidence without introducing runtime-process risk. Family 3 remains the next software architecture rung; family 4 remains authorization-blocked.

## Decisions

### Decision: represent WKV execution as an explicit layer-zero mode

The existing full-model token core remains the source-FP32 default. A pure internal mode supplies either the ordinary CPU recurrence, a CPU recurrence surrounded by BF16 round trips, or an externally observed raw output/post-state pair for layer zero. Later layers continue through the existing CPU equation. Existing public receipts must remain unchanged.

### Decision: retain complete model state per path

Each path owns attention previous-input, channel previous-input, matrix, and independent oracle state for all twelve layers. The observed, reset, and transposed paths branch only after the same physically perturbed token-two execution, preventing unrelated state changes from masquerading as retained-state sensitivity.

### Decision: lock both model vectors and layer-local coverage

Each path records final hidden state, complete logits, all layer host/matrix states, and token-three output after every layer. This makes skipped, duplicated, or reordered layers observable. The untied BF16 head retains its independent top-two audit.

### Decision: require model-level negative controls

The reset control zeros only the physical layer-zero matrix before token position three. The orientation control transposes each physical per-head matrix while preserving all host and later-layer state. Both controls must diverge from the observed path in complete state and logits, while the observed path must remain closer to expected BF16 than to either control.

### Decision: preserve narrow authority and invocation

The new replay invokes and fingerprints both accepted prior receipts, validates the exact package-owned evidence, and accepts only `--evidence-root PATH`. Source scans reject process/device surfaces. The receipt continues to label the enclosing hardware session `unsafe`.

## Risks / Trade-offs

- Layers 1–11 and token position three execute on CPU, so a passing result establishes composition structure rather than hardware execution.
- The physical perturbation may not change the greedy token even when complete logits differ; complete-vector fingerprints and deviations remain authoritative.
- Shared Rust equations can share implementation defects; unchanged framework parity, scalar recurrence oracles, direct BF16 head ranking, reset, and transpose controls provide independent checks.

## Validation plan

- Establish passing observed-layer, state-carry, and package baselines before modifying core logic.
- Require prior canonical receipt identities to remain unchanged.
- Build and run the fixed all-layer replay twice and require byte identity.
- Require all twelve token-three layer outputs, finite complete states/logits, direct head ranking agreement, and named source/expected/control deviations.
- Reject malformed evidence and missing, extra, or reordered arguments.
- Rebuild framework parity, historical harness checks, boundary-device compatibility, host layout, decode-reader ABI, and architecture checks.
- Prove the runtime closure remains fixture-free and contains neither Python nor PyTorch.
- Run focused formatting, clean detached-worktree Cairn validation/gates, sync, and archive.

## Validation evidence

The accepted observed-layer and state-carry receipts remain byte-identical with BLAKE3 identities `0f2e08a9966672ab8d076ec2a601e336c0e0022ea4af023e472a7bbc05ba6d18` and `58e433a04a10319293b18d6003659b53a04a95e9cf9cc7b540c2448c98ed6a33`. The all-layer receipt is 41,591 bytes with BLAKE3 `74306bd245d0bf3b4de9ce5c5f0736edcb516ac9556bc67e7c8116653de973ed`; repeated fixed-invocation runs are byte-identical. The shared library, observed composition core, imperative shell, and Nix package definition have BLAKE3 identities `31f0776b5a94d838c49d8b0aece9686490ac5c11d38fd85ce2a0537320f77221`, `e6aff087ec6694566760e8568497141be6be3d1d3127b0472a888acad089e3ea`, `89c76a8be7cad47d9991c247521930c2c01f5cd9124cf2c7149be43592007e4a`, and `83e528303867a1f8cdd6c26a1eae5e458f015944a23b7b0246121d016071b511`.

For token sequence `[1, 2, 2]`, every path records twelve ordered third-token layer outputs, 9,216 attention-state values, 9,216 channel-state values, 589,824 matrix-state values, 608,256 complete recurrent-state values, 768 final-hidden values, and 65,536 logits. Source FP32, expected BF16, and observed physical-seed paths all rank token `2` first and token `33` second. Their greedy margins are `3.9154253`, `3.917026`, and `3.9139075`, respectively, and every direct BF16 untied-head top-two audit has zero reported deviation.

The observed path differs from expected BF16 by `0.024749756` in final hidden, `0.005589485` in complete logits, and `0.01061058` in complete recurrent state. It differs from source FP32 by `0.02338028`, `0.008767128`, and `0.0155649185`, respectively. The observed complete layer output, final hidden, logits, and complete state have BLAKE3 identities `61382a251ce618622dcd695737b08fe8981f5e8d435b8261887237d97210dc64`, `60de3a8afa23de56006671a09aca735e17da2946807e827b5dc731cb539859ec`, `b1ba3cdf9579c2233d16e22168e0aa4da0447273c10ff7229ecfda0a34d8482e`, and `fa8b37ad9d490ea8152e1eb3abba522348e1c5181bb94f031a03fec907f4e9bb`.

Resetting only the physical layer-zero matrix before token three changes complete logits by `0.742733` and complete state by `3.5060477`. Transposing each physical per-head matrix changes them by `1.1483517` and `4.229019`. Both controls branch from deep clones of the same physically perturbed token-two state, retain identical host and layers 1–11 state at the branch point, and remain far farther from the observed path than expected BF16. The fixed model-weight slot validation and exact ordered layer-output receipt prevent skipped, duplicated, or reordered layers from retaining authority. An advisory adversarial review specifically called out exact injection, branch independence, layer order, and untied-head auditing; exact prior-receipt identities, deep vector clones, twelve ordered fingerprints, complete-vector controls, and the direct BF16 head audit cover those discriminators.

Clean outputs are `/nix/store/w5h3c1fih1clkc1wsi138vcmqfxmcg1s-rwkv-layer-harness-0.1.0`, `/nix/store/1w44d1mykz4m6ldy7rx20f1c9mkyv9g5-rwkv-ttwkv7-observed-model-carry`, `/nix/store/lwhp2w87xm0w6ii3l8ilvwafhhicqa15-rwkv-ttwkv7-observed-state-carry`, `/nix/store/pl6r0zm0kj28ym5nbans7922brn4djb4-rwkv-ttwkv7-observed-layer-replay`, `/nix/store/2i48hslbchcyac51ghiipkwps66fiqqf-rwkv-layer-harness-torch-equation-parity`, `/nix/store/mding08sg5cflyf2jmqzpjrq1jbiv7dd-rwkv-ttwkv7-boundary-device-check`, `/nix/store/5y51r7z7qc7ffry680va1mq1dkiczj41-rwkv-ttwkv7-host-layout-check`, `/nix/store/94nx0hsh5wlgpvmlygdw92hkf3dy101g-rwkv-ttwkv7-decode-reader-check`, and `/nix/store/b85dmwmfg7zjlszfihpa9bwxg9k04srz-ttwkv7-architecture-check`. The runtime closure contains fifteen paths, contains neither Python nor PyTorch, and excludes the physical evidence directory.

The mechanically rebuilt, still-`not_run` boundary package is `/nix/store/s6jlmvwcln0ipn5njpc8bjh5hgbb70cq-rwkv-ttwkv7-boundary-device-0.2.0`. Its plan ID is `cbe0de5c2b3d0ea589553168f17a03b704d01695a932c1f5efed43ff1af3cc78`; plan and not-run receipts have BLAKE3 identities `03a7d05a4eb3d522d9791764cad6ca2407894593345ff955d6e0a33aad62c178` and `aba4ff445bfbe0e4463c1fa69b95a7d8fc5f0001ed7104455e9c4f056e0a0ffd`. No runbook, device, process, or owner-service action occurred.

Positive deterministic replay, canonical prior-receipt preservation, classification/output/state mutation rejection, missing/extra/reordered invocation rejection, reset and transposed-state discrimination, source-surface scans, framework parity, historical package receipts, boundary-device compatibility, host layout, decode-reader ABI, architecture checks, formatting, and the archived runbook checker/self-test pass. Clippy remains unavailable because the evaluated repository dev shell and direct host environment do not provide `cargo` (`exec: cargo: not found`); Rust compilation, unit tests, install checks, and all relevant Nix checks pass. Cairn sync accepted the requirement with receipt `6678f6c257a1175033bb7e74387f40ea77f8c6ea7ed67b586cbc8347335ed643`; archive execution produced receipt `deefd503e4135f4b5ddd14d351530973eb817cc6fac514f713afb59a1f2796c5`. Clean post-archive validation reports `changes: 0`, `valid: true`, and no issues or substance issues.
