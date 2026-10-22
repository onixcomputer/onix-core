## Context

The baseline runtime defect was exercised through the actual live Trellis source module. A previous green full Verus corpus does not establish consistency of trusted axioms. Global injection of 128 input bits into 64 output bits cannot be implemented.

## Decisions

1. Preserve input-hash binding using an exact 128-bit pair commitment, not a narrowed input domain, lossy digest, replacement axiom, or compatibility alias. State explicitly that original data/metadata hashing and authentication remain outside this finite structural model.
2. Let real pinned Nemotron edit only an isolated current snapshot. Parent review owns public API migration, meaningful contracts and integration. Freeze all unrelated inputs and reject added trust escapes.
3. Use the existing OpenCode local-provider configuration with task-local state, an exact edit allowlist and only a no-argument source-bound verifier command. Retain actual prompts, attempts, verifier receipts and input identities.
4. The model's verifier may target snapshot-integrity for iteration. Acceptance must independently verify the full affected current source, exercise public runtime entry points including the recorded collision, and enforce the live trust inventory.
5. Reuse the existing Spark launcher unchanged. Preserve current original container identities/configuration privately; stop the three-rank deployment as a unit, run one Nemotron replica on `spark-e442.local`, then restart original workers before the head. Require a real restored completion.
6. Update native Cairn records and existing documentation only after observed checks. Do not alter historical campaign evidence or unrelated working-tree changes.

## Acceptance

A real source-bound Nemotron attempt; an assumption-free executable pair commitment and injectivity proof preserving meaningful tamper contracts; negative runtime checks for the prior metadata collision, independent data changes, combined-value changes and chain mismatch; full production Verus acceptance; active caller/trust-policy migration; native lifecycle validation; original DeepSeek identity/configuration and inference restored.
