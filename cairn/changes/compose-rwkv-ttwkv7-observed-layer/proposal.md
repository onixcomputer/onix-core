## Why

The exact device-1 ttWKV7 boundary process completed one real-weight workload and produced finite passing output and post-state evidence, but the accepted CPU layer reference still consumes only its own recurrence result. The next smallest device-free rung is to preserve that terminal physical evidence and prove how its observed BF16 recurrence values compose through the existing layer-zero attention and channel-mix suffix. This closes a concrete integration gap without requiring another hardware process or claiming that a complete layer ran on the P150.

## What Changes

- Preserve the exact terminal device receipt, session evidence, classification, raw BF16 writer/output/post-state artifacts, diagnostic log, and final board snapshot as immutable checked evidence.
- Refactor the fused Rust time-mix implementation into pure preparation, recurrence, and attention-finish cores shared by the accepted CPU path and the observed-artifact replay.
- Add a strict device-free replay that injects the observed raw WKV output and post-state into layer zero's second-token CPU suffix and compares it with both the expected BF16-boundary path and the accepted FP32 full-layer path.
- Add deterministic receipts, complete artifact/source/session authority checks, closure isolation, and positive and negative tests that reject changed bytes, dimensions, source hashes, outcomes, metrics, ordering, or invocation shape.

## Impact

- **Files**: `pkgs/rwkv-layer-harness/`, a dedicated checked evidence subtree, `flake-outputs/ttwkv7.nix`, and this Cairn change package.
- **Testing**: pre-change and post-change Rust tests; deterministic replay; adversarial artifact fixtures; historical layer/token/decode/text/prompt/framework/boundary receipts; package closure checks; focused Nix builds; formatting; and clean Cairn validation/gates.
