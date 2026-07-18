# Design: Real-model ttWKV7 dispatch routing

## Goal

Route the third token of the real twelve-layer RWKV checkpoint through the accepted framed dispatch ABI, starting from the exact model state produced after injecting the accepted physical layer-zero second-token WKV output and post-state. Completion requires twelve ordered model-derived requests, twelve request-bound responses, oracle agreement, retained-state controls, deterministic receipts, historical receipt preservation, and no hardware/process surface.

## State reconstruction

The fixed evidence loader first reproduces and fingerprints the accepted observed-layer, state-carry, observed-model-carry, and dispatch-ABI receipts. It loads the pinned checkpoint, executes token one on CPU, injects the exact physical layer-zero token-two output/state, and executes token-two layers 1–11 on CPU exactly as the accepted model-carry rung did. Each layer owns independent attention-previous, channel-previous, matrix, and oracle-matrix state.

## Framed third-token execution

For token index two (zero based), each layer performs host-side pre-normalization and time-mix projection in FP32. Layer zero establishes the token-local `v_first`; later layers consume it in their value interpolation. The resulting `a,w,k,v,r,b` vectors and that layer's retained matrix are encoded into the canonical BF16 request frame. A thin device-free dispatcher decodes the frame, executes the shared CPU matrix recurrence, encodes a BF16 response, and validates exact sequence/call/token/layer/dimension/request authority before the model consumes output or state. Host attention projection, residuals, normalization, channel mix, and the untied language-model head remain FP32.

The framed path is compared with an independent path that applies the same BF16 transport points but uses the separately ordered recurrence oracle instead of dispatch framing. Complete-vector deviations are bounded and recorded.

## Controls and authority

The retained path branches from the reconstructed physical-seeded token-two state. A reset control zeros all twelve matrix states, and an orientation control transposes every per-head matrix before the third token. Host attention/channel state and model weights remain identical at the branch point. Both controls must diverge from retained output, complete state, and logits.

The receipt locks the prior model-carry and dispatch-ABI receipt identities, physical evidence identity and `unsafe` outcome, sequence identity, request/response frame sizes, twelve ordered frame hashes, twelve layer outputs, all recurrent state vectors, final hidden state, all 65,536 logits, and an independently audited top-two untied-head ranking.

## Functional core and shell

Pure cores prepare model-derived requests, canonicalize frames, validate responses, finish attention/layer suffixes, and reduce transcript identities. The imperative binary accepts only `--evidence-root PATH`, reads the fixed package-owned evidence and checkpoint, invokes no child process, and writes canonical JSON.

## Negative validation

Tests and Nix checks reject missing, extra, or reordered arguments; changed physical evidence; changed prior receipt identities; stale, reordered, duplicated, or malformed response authority; layer-order drift; reset or transpose controls that fail to diverge; non-finite vectors; process/device symbols; physical evidence entering the ordinary runtime closure; and changes to historical receipt bytes.

## Non-claims

The CPU dispatcher is not a persistent process or Metalium implementation. No third-token WKV call executes physically, no complete layer/model executes wholly on Tenstorrent, and no hardware-backed generation, serving, throughput, latency, general P150 compatibility, or new authorization is established. The accepted physical session remains `unsafe`.

## Validation evidence

The fixed replay emits a 43,080-byte canonical receipt with BLAKE3 `81c3b5c9904d2469b89d3f6732609514996fbe910a0c9ff0c150fb6044832b5d`. It preserves the exact prior dispatch-ABI, observed-model-carry, state-carry, and observed-layer receipt identities `65ab5583647dc79b1d1c78870cedccd6f556a58264dd9b9640c9214f010fe431`, `74306bd245d0bf3b4de9ce5c5f0736edcb516ac9556bc67e7c8116653de973ed`, `58e433a04a10319293b18d6003659b53a04a95e9cf9cc7b540c2448c98ed6a33`, and `0f2e08a9966672ab8d076ec2a601e336c0e0022ea4af023e472a7bbc05ba6d18`.

The reconstructed physical-seeded token-two attention, channel, matrix, and complete states contain 9,216, 9,216, 589,824, and 608,256 values and have BLAKE3 identities `ad0016542abe85df264a65b9083b30fe61b844cd568a8696fe457d853c47a0fb`, `9e938d7dfbfc02c0b16a064a28c7fcbb10dc4294d8b00fea7fd3aa8af22a5c95`, `b0984844f004f2a92bd06efcdc5dddb692e69948b9bb0d4599c4d5c3c6ce4afb`, and `07639ace76eb47cd7ce733b0754d1905af3c117701821850da9abfc695d232dd`.

The retained, reset, and transposed paths each contain exactly twelve 107,588-byte requests and twelve 99,940-byte request-bound responses. Their sequence identities are `e8fcf5046591b9ca0147ece598b858b07744cc2a4ca24a6a8e8944d926d54cab`, `e8a1ca1eec4cad16201e5214d1c30e31ba3dc3a0d8641e3eda7b99d0269384e2`, and `3cf1c3dc2f1ce354f4e21aae62affaf0637c0af09c1d84d369bc08becb894020`; transcript identities are `c425dfc393850ff6a5041837d7904bb75c825be14e16d9df775d1b510cb04d38`, `1285fddeabae7153596a3f5bc6f9cc6063d441046a6ab261123dc6c8085c2715`, and `ae85f1bb6595bbfde0b1c7e2d90ab3aa84e4b3e537d3d7baf5d286557aeb78ed`.

The framed retained path differs from the independently ordered all-layer BF16 oracle by `0.001953125` in raw WKV output, `0.0009765625` in matrix post-state, `0.0001604557` in layer output, `0.00035476685` in final hidden, `0.00018692017` across all 65,536 logits, and `0.0009765625` in complete recurrent state, below the fixed `0.002` ceiling. Both rank token `2` first and token `33` second, with direct BF16 untied-head agreement. The retained path differs from reset by `134.51514` in final output, `15.3446` in logits, and `55.0` in complete state; it differs from per-head transpose by `90.17365`, `22.17935`, and `54.99176`. Reset ranks `[92, 11]`, while transpose ranks `[47, 1753]`.

An advisory adversarial review specifically requested proof that controls change only matrix state and that new physical-call accounting remains zero. Pure validation now checks every layer's host attention/channel state and accumulated deviations remain byte-identical across branches, verifies exact zero or per-head-transposed matrix/oracle state, and records `physical_wkv_call_count: 1` with `new_physical_wkv_call_count: 0`.

The dispatch core, observed-model composition core, library export, imperative shell, and package definition have BLAKE3 identities `e9ba1a26e1410b176090fc5227f572ff36983a59e009ac1b3bce7b0da964f5a4`, `30249445fa9f90bc80e49f139fe8ad2cb1a29c45d50492075c6afc66d366c951`, `6a5d0f6abd7226d157d25cc2758e884d79d618df5dcce49b34e23ac49df2f260`, `393dea4563a222e6dd6c06601829e19f053288d0433bf9a9f799d7a10576227b`, and `75782b854bc3aa6a103ca91119f4c20a7a7dd402e6af22e0c6a2850fe811d75d`.

Focused output is `/nix/store/rpyyvz29xb78sh1a44za0ycm7xxnrjdc-rwkv-ttwkv7-observed-model-dispatch`; historical clean outputs include `/nix/store/9h984sxwy42n1z3c48j19dpfc6myjar6-rwkv-ttwkv7-dispatch-abi`, `/nix/store/73a5pk3f1ks3n93y7cswz89fz1iz5am4-rwkv-ttwkv7-observed-model-carry`, `/nix/store/l6c7n28b52z1vr81h51dd1zx94jw52hh-rwkv-ttwkv7-observed-state-carry`, `/nix/store/3jzc2lmybdsk6jm6xn67cwyygznbii2z-rwkv-ttwkv7-observed-layer-replay`, `/nix/store/0f853wyjk1b2yd3s9m1sc8wdrfi5m4hb-rwkv-layer-harness-torch-equation-parity`, `/nix/store/xv0smlgzz69c4pw00k21509mi0ifz889-rwkv-ttwkv7-boundary-device-check`, `/nix/store/509gk2g01m194j055150l8yn7s6rrkwx-rwkv-ttwkv7-host-layout-check`, `/nix/store/n74ycbnwzfns0dqgk7amjs4mi3h19lf2-rwkv-ttwkv7-decode-reader-check`, and `/nix/store/b85dmwmfg7zjlszfihpa9bwxg9k04srz-ttwkv7-architecture-check`. The runtime package `/nix/store/7cbbl2aib81i1acgq6lc9v8gla77ybrn-rwkv-layer-harness-0.1.0` has a fifteen-path closure containing neither Python nor PyTorch and excludes physical evidence.

The mechanically rebuilt, still-`not_run` boundary package is `/nix/store/h70zj4bhk3sq7034my3czkab0qx5hdca-rwkv-ttwkv7-boundary-device-0.2.0`. Its plan ID is `629c422d9e43ec962a5840a44b0ab2465ffa3c9de8035ff3ce9071d0cb5b9b6f`; plan and not-run receipts have BLAKE3 identities `d45b05ed91e54a4fc3fb854399c80e79bf5db8729b71b8c5a2edad044d26e398` and `c3acf42ac10140174fb80734daaf388f5edd8fcee5ef240e82517c8bae3fb1a6`. The archived runbook checker and self-test pass. Clean detached-worktree Cairn validation reports `valid: true` with no issues or substance issues; proposal, design, and tasks gates all pass. Clippy remains unavailable because the evaluated repository development shell does not provide `cargo` (`exec: cargo: not found`), while Rust compilation, unit tests, install checks, and all relevant Nix checks pass. No runbook, hardware process, device, or owner-service action occurred. Cairn sync accepted the requirement with receipt `72f1bc3446eebb10cf315f94e22ec52d56978fc088287283002d6faf2dab29d0`; archive execution produced receipt `d03a0ef831c6d2b38567edae13f436c4e0adaa803bf1d14a0b40fce15eae971f`. Clean post-archive validation reports `changes: 0`, `valid: true`, and no issues or substance issues.
