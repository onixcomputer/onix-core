## Context

The authorized recovery session used physical device 1 exactly once. The wrapper process exited zero without timeout, initialized Metalium, enqueued one workload, emitted `rwkv ttWKV7 boundary device probe: PASS`, and wrote complete writer, output, and post-state artifacts. Output NMSE was `1.4987897011677202e-05`; post-state NMSE was `1.5454054999825693e-05`; both are below the fixed `0.06` ceiling. The terminal session remains `unsafe` because owner HTTP health did not return within 60 attempts at two-second intervals. The owner later returned HTTP 200, the independent rollback completed, and the service remained active with no restart, but that supplemental recovery does not rewrite terminal classification.

The CPU reference already executes the full layer and constructs the same logical second-token WKV inputs. Its `time_mix` function currently fuses projection/input preparation, matrix and scalar recurrence, group normalization, gate correction, and output projection. A replay cannot safely substitute physical recurrence output until those stages have explicit pure boundaries.

## Search contract

**Goal:** choose the smallest device-free rung that uses the physical result to advance toward complete-layer execution.

**Completion evidence:** exact raw evidence authorities are checked; observed physical output and state are decoded in the accepted orientation; shared pure preparation/finish cores preserve historical receipts; a deterministic complete-vector replay composes observed values through the layer suffix; positive and negative checks pass without a device.

**False completion:** evidence-only documentation, rerunning the CPU recurrence instead of injecting observed bytes, comparing sampled elements, hiding the terminal `unsafe` classification, widening the hardware NMSE ceiling, claiming a wholly device-executed layer, or starting another hardware process.

**Budget:** four mechanism families, one advisory review round, one adversarial audit round, focused repository reads, and deterministic local checks. Allowed outcomes are validated or an exact implementation blocker. Both advisory review calls returned `fetch failed` and contribute no evidence.

| Family | Mechanism | Result |
| --- | --- | --- |
| Evidence-only | Check in typed hashes and terminal classification | Preserves history but does not test composition; rejected as insufficient. |
| Observed suffix replay | Inject exact physical raw output/post-state into the shared CPU suffix | Smallest route that tests a new integration boundary; selected. |
| Hybrid runtime runner | Add host preprocessing/suffix around a future device WKV call | Valuable later, but requires runtime orchestration and fresh hardware evidence; deferred. |
| All-Metal layer | Port norms, projections, and channel mix to Metalium now | Much larger gap and weakens iteration quality; deferred. |

## Decisions

### Decision: Preserve physical evidence in a dedicated check-only subtree

**Choice:** Copy the exact terminal receipt, session/classification records, diagnostic and board records, and complete raw BF16 artifacts into a dedicated source fixture consumed only by a cross-package check.

**Rationale:** The replay must remain reproducible after `/var/tmp` evidence disappears. Keeping evidence check-only prevents it from entering the ordinary ttWKV7 runtime closure or changing the existing argument-free reference package's historical authority.

### Decision: Split time mix into prepare, recurrence, and finish cores

**Choice:** Extract a pure preparation result containing WKV inputs, projected value, and gate; keep matrix/scalar recurrence pure; extract a pure attention finish that applies group norm, correction, and output projection to a supplied raw WKV vector.

**Rationale:** The original CPU path and observed path then share all non-recurrence math, while the injected boundary remains explicit and testable without mocks or I/O.

### Decision: Compare three complete paths

**Choice:** Produce the accepted source-FP32 result, an expected-BF16-boundary composition, and an observed-device composition. Record complete-vector deviations and BLAKE3 identities for attention output, final layer output, and recurrent state.

**Rationale:** Expected-versus-source isolates BF16 transport effects; observed-versus-expected isolates physical recurrence effects; observed-versus-source reports their composition. A single comparison would conflate these mechanisms.

### Decision: Keep session safety and numerical validity independent

**Choice:** Require the exact terminal `unsafe` classification and safety issue while separately validating the device receipt's passing numerical result.

**Rationale:** Delayed owner health must not erase the valid physical arithmetic evidence, and valid arithmetic must not erase the terminal safety classification.

## Adversarial audit

The replay must reject a recomputed receipt with one changed semantic field even if artifact bytes are unchanged; wrong or truncated output/state/writer bytes; swapped output and state; transposed state; missing marker; process count other than one; timeout; changed source hash; non-finite or threshold-equal metric; changed fixture or ordered-artifact authority; and invocation suffixes. Refactor tests must fail if the observed path silently calls CPU recurrence, if source and observed paths share a mutable state buffer, or if historical receipt bytes drift.

## Risks / Trade-offs

- Checked-in hardware artifacts increase source size by roughly 300 KiB, accepted to make the rung reproducible.
- The observed suffix uses FP32 host-side projection/gate intermediates around a BF16 device recurrence, so it models a hybrid boundary rather than an all-BF16 or all-device layer.
- A passing replay does not authorize or validate another device process.

## Validation evidence

The accepted check-only evidence bundle contains all thirteen terminal authorities and has domain-separated BLAKE3 `2c184f63f7ba298aea7f3eabd189494b4b1d65e9e21c8cc7745c38451d62aa31`. Its typed Nickel export has BLAKE3 `3d7c9c9f256612f5885fad7cd7aef9b73dfcea11df83da8fbe28cf7a625dab54`. The terminal classification remains `unsafe`, with no success claim, while the hardware receipt independently retains one process, one workload, finite strict NMSE passes, complete raw artifacts, and the exact production reader/compute/writer identities.

The shared core now separates time-mix preparation, matrix/scalar recurrence, attention finishing, and the complete attention-plus-channel-mix layer suffix. Rebuilding the package preserved all accepted layer, token, stateful-decode, fixed-text, bounded-prompt, BF16 boundary, and framework receipts. The observed replay source and shell identities are `91477f48a2c04d4e1f7e7474766dc97c0c6881d0796736321bbe99f2b8211240` and `39a54f0fd9aa5f70e32fb423daada67334d99524bb1a14ef6faef04e32b98f3b`.

The deterministic replay receipt is 7,813 bytes with BLAKE3 `0f2e08a9966672ab8d076ec2a601e336c0e0022ea4af023e472a7bbc05ba6d18`. Its observed hybrid attention and final-layer fingerprints are `3ceb34498ce82d176e17a2372a3213e7008f13b429239f8ff3d718bafe464d37` and `f9b56d68f21cea629b101ebe6d2c56e709ace8beb03f37b51cfc20beead95581`. The expected-BF16-boundary counterparts are `b577a38ed9cad20ddece194f1618fd27b27a81f72cd780a87ddbf4e51d9ac39f` and `67a8e5d826efafcb9fbdcfbdcc3135d80352ba5d34e8cbd826b0ae9efd6f0b20`; the source FP32 attention identity is `f6f21abaf40152a89d54287b32b5e1da316c2b21432def1cf918006ba3b87763`.

The physical raw-output deviation versus expected BF16 is `0.00048828125`; post-state deviation is `0.0078125`. Through the shared CPU suffix, observed attention differs from expected BF16 composition by `0.0011649132`, and observed complete layer-zero output differs by `0.0017949939`. The observed complete output differs from the accepted source FP32 layer result by only `0.00022334047`. These are complete-vector maximum absolute deviations, not sampled values or new generic tolerances.

Clean detached-worktree outputs are `/nix/store/cnz76s0pi78s7lmh6jlr7cqzmw8h84pv-rwkv-layer-harness-0.1.0`, `/nix/store/x1lxa3prs31fvmrg1nhmrsxjhlsnxhcx-rwkv-ttwkv7-observed-layer-replay`, `/nix/store/xzavb3pdrsrc3pdp10n1mp89lz8wkz49-rwkv-layer-harness-torch-equation-parity`, `/nix/store/43lz5sbycfarx6g4vv20v8lddvhn7awc-rwkv-ttwkv7-boundary-device-check`, `/nix/store/8jb9p6xj6qzqg1jpn2llgvcpd64k6nj7-rwkv-ttwkv7-host-layout-check`, `/nix/store/bs7ky18pja5x85kijvy3p29ifxaw1iq7-rwkv-ttwkv7-decode-reader-check`, and `/nix/store/b85dmwmfg7zjlszfihpa9bwxg9k04srz-ttwkv7-architecture-check`. The rebuilt boundary package is `/nix/store/ninbz961d7dm7iblh1jr0x6sjrwxc2r8-rwkv-ttwkv7-boundary-device-0.2.0`; its derived plan remains `not_run` and no runbook or device process was invoked.

Positive replay, repeated determinism, typed evidence export, malformed classification/receipt/output/state/writer/argument fixtures, runtime closure isolation, focused formatting, the archived runbook checker and self-test, and clean Cairn validation plus proposal/design/tasks gates pass. Clippy could not run because the repository dev shell requires missing `/run/secrets/vars/nix-signing-key/key`, and direct host Cargo is absent; Rust compilation, unit tests, install checks, and `-D warnings`-independent Nix checks remain passing evidence.
