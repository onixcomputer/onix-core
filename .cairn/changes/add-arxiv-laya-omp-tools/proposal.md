## Why

OMP needs direct access to the requested arXiv Complete corpus and the requested Laya decision model without confusing a dataset with a chat model or consuming the desktop's scarce memory.

## What Changes

- Add private CPU services on Aspen2: complete metadata search with selective paper-text retrieval, and real Laya typed inference.
- Register `arxiv_corpus` and `laya_decide` as native OMP tools with pinned resource provenance and explicit limits.
- Declare packages, service settings, placement and desktop client installation in Onix Core.
- Add a pinned compensated Vulkan FP32 Laya provider on Aspen1 without changing existing CPU providers or the desktop's default research route.

## Impact

- **Files**: `pkgs/arxiv-corpus`, `pkgs/laya`, `pkgs/laya-cpp`, `pkgs/mesh-research`, corresponding Clan modules, service registries and inventory, `modules/llm-agents`, and package exports.
- **Testing**: build packages, prepare the complete corpus, perform real text retrieval and model inference through OMP, check private binding and unchanged unrelated services, validate native Cairn records.

## Opt-in stuck-loop advisory

Add `/laya-watch on|off|status` to the existing managed research extension. Monitoring is session-local and off by default. It scores a small in-memory observation window through each client's existing Laya route and supplies optional notes, never execution, permission, retry, or completion decisions. Preserve all existing services, routes and tool results.

## Opt-in arXiv relevance reranking

Extend only the managed OMP `arxiv_corpus` registration with optional, search-only `rerank_query`. Keep `query` as the original lexical FTS expression and use the separate natural-language relevance query to score the returned candidates through each client's existing Laya route. The raw corpus HTTP and Mesh/MCP operation schemas remain unchanged. Preserve complete results, BM25 scores, citations and provenance; only successful opt-in scoring changes their order. Inference failure returns the untouched original order with a visible fallback reason, while caller cancellation propagates. Bound classifier inputs and reject potentially truncated predictions. Keep the feature opt-in pending a held-out relevance comparison; this addition makes no deployment or quality claim.

## Opt-in arXiv multi-query retrieval

Add OMP-only, search-only `queries` as an alternative to `query`, accepting 2–4 complementary lexical expressions supplied by the main model. Do not generate queries or hardcode paper IDs. Share one bounded candidate budget, retrieve in parallel through the existing corpus route, merge by round-robin rank position and deduplicate by paper ID while retaining every query-specific occurrence. Keep the existing single-query execution/results unchanged. Optional `rerank_query` uses the same fixed Laya rubric and client-specific inference route for either retrieval mode; multi-query results retain their merged baseline position rather than implying a global BM25 order.

Requirement `onix.research-tools.arxiv-multi-query` covers pre-I/O bounds, immutable provenance, complete failure/cancellation semantics and matching text/details. Package the shared helper beside both managed entrypoints without changing raw corpus HTTP, Mesh/MCP schemas, endpoints, services or the watcher. Native behavior and scoped deployment are verified on both clients; observed proof is appended under `arxiv_multi_query` in `verification.json`, preserving all earlier evidence. On six frozen questions, multi-query found 7/12 preselected primary papers versus 2/12 for the original query, but a single `OR` query using the same expansions found 10/12. Both expanded methods recovered the two RWKV motivating targets. Keep this feature opt-in: fixed per-query quotas trade depth for breadth, and the experiment does not establish superiority over a well-formed single query or corpus-wide recall.

## Caller-labeled Laya question evaluation

Add native OMP-only `laya_evaluate` to evaluate one caller-supplied choice, score or noul question against 2–8 explicitly caller-labeled examples. Validate the complete input before inference, keep IDs and expected answers out of prediction requests, and use each client's existing `/predict` route serially under one combined 15-second deadline. Malformed replies, errors, cancellation or model/token-budget drift fail the whole evaluation; no retries or partial metrics are returned.

Requirement `onix.research-tools.laya-evaluate` covers strict response parsing, preserved original prediction/provenance fields, per-example results and timing, classification accuracy/Brier scores or score mean absolute error, and visible possible-truncation counts. Expected labels are not independently verified, tiny samples do not establish calibration or generalization, and neither metrics nor uncalibrated confidence authorize actions. Input-token equality with the reported context limit is retained and flagged, not excluded; lower reported usage cannot rule out earlier 192-token question/option truncation.

Package the canonical shared `laya-evaluate.ts` beside the existing helpers on Mac and desktop. Keep `operations.json`, raw HTTP/Mesh/MCP capabilities, existing tools, services, endpoints, model settings, routing and watcher activation unchanged. Phase 9 records the completed implementation, fresh native OMP checks on both clients, and scoped client deployment in the appended `verification.json` section. The illustrative caller-labeled results are not calibration or generalization evidence and do not replace any prior outcomes.

## Paired baseline question comparison

Extend the existing native OMP `laya_evaluate` operation with optional `baseline_question`, rather than adding another tool or a raw service operation. Compare both questions on the same 2–8 caller-labeled examples, retain each prediction, and report candidate-minus-baseline metrics and per-example loss changes. Keep the default single-question behavior intact. Requirement: `onix.research-tools.laya-paired-evaluation`.

Validate compatible types and label spaces before any inference, run baseline then candidate for each example under the existing single 15-second deadline, and enforce one provenance/token-budget identity across all predictions. Do not generate labels, tune questions, choose a winner, exclude token-limit examples, retry failures, or return partial results. Equal label names cannot establish equal task semantics; this remains a bounded caller-labeled diagnostic, not calibration, a significance test, or authorization.

Phase 10 records the implemented comparison, native checks on both existing routes, unchanged entrypoints/manifests/other helpers, scoped deployment, and preserved historical evidence. The frozen illustrative choice cases improved average Brier loss while one case regressed; the tool preserves that distinction instead of hiding it behind an aggregate winner.

## Native unlabeled Laya batch classification

Add native read-only `laya_batch` for one caller-supplied choice, score or noul question over 1–16 unlabeled items `{id, state}`. Requirement: `onix.research-tools.laya-batch`. Validate the complete question and every item before inference, preserve input order and full original responses/provenance, and report per-item actuals, timing and token-limit flags plus an operation-level token-limit count. Report the fixed 0.5 decision threshold only for noul, with ties true. Do not invent expected labels, accuracy, Brier loss or MAE, sort/group items, clip text, retry or authorize actions.

Extract the evaluator's proven question/item validation, SDK passthrough response factory and serial prediction engine into canonical `laya-predict.ts`. Both evaluation modes and the new `laya-batch.ts` consume that same engine, with one 15-second deadline, one provenance/token-budget identity and exact cancellation across each complete operation. Keep existing evaluation metrics, baseline-then-candidate ordering and limitations intact; each native entrypoint instantiates one SDK parser shared by evaluation and batch. Package both new helpers beside existing helpers on Mac and desktop. Preserve raw `laya_decide`, arXiv tools, `operations.json`, services, routes, model settings and watcher behavior.

The configured base checkpoints remain English-only and are not the separately fine-tuned typed-decisions model. Probabilities are uncalibrated and confidence is not label probability; unlabeled predictions establish neither accuracy, calibration, generalization, safety nor authorization. Token-limit equality is retained as possible truncation; a false flag cannot exclude earlier 192-token question/option clipping. Phase 11 is implemented, natively verified and deployed through the scoped client-extension mechanisms on both clients. Observed integration checks and deployed hashes are appended to verification.json; every earlier phase and outcome remains intact. No current-session reload or watcher activation change was performed.

## Phase 12: Five native advisory tools

Add native read-only `laya_failure_triage`, `laya_diff_triage`, `laya_duplicate_check`, `laya_evidence_match` and `laya_completion_check`. They classify supplied English logs, diff hunks, candidate pairs and acceptance evidence, preserve original references and full predictions, and make bounded advisory decisions without generating explanations, fetching references, executing runbooks/tests, merging records or authorizing completion. Reuse the common prediction engine, SDK parser and identity validators; keep all existing raw operations, routes, services, model settings and watcher behavior unchanged.

All five implementations, 201 tests and actual native proofs passed on both clients. Scoped client packages are installed; Phase 12 records the observed outcomes and retained evidence. Package the Mac extension as one copied store directory, matching desktop: individual Home Manager store files break runtime sibling imports. Preserve all prior verification outcomes; retain the larger new native evidence in a referenced JSON artifact rather than repeatedly duplicating it into the existing near-1-MiB verification index. Uncalibrated advisory classifications do not establish root cause, vulnerability, nonduplication, global truth, acceptance or permission to stop.

## Phase 13: Five additional workflow advisories

Add native read-only `laya_context_rank`, `laya_test_relevance`, `laya_issue_route`, `laya_review_triage` and `laya_requirement_conflict` through the existing client routes. These tools rank caller-supplied context/tests, compare described issue responsibilities, independently classify/prioritize review comments, and inspect candidate requirement conflicts. All original records are retained; no pruning, skipped-test permission, ownership assignment, comment resolution, requirement rewriting or global-consistency claim is introduced. Implementations, integration and both scoped package builds/deployments are complete. The pinned Bun 1.3.13 run passed all 245 tests across 19 files with 1375 assertions; both clients also passed actual native execution, including 54 invalid-before-I/O cases, 51 injected failure cases and nine explicitly controlled aggregation cases each. These are contract checks, not classifier-accuracy or calibration benchmarks.

Complete observed outcomes are retained in `laya-workflow-mac-verification.json` and `laya-workflow-desktop-verification.json`, referenced by `laya-workflow-verification.json` and the appended master evidence section. All 37 prior master sections and the previous advisory artifact remain unchanged. Owned proof supervisors were stopped and temporary driver directories removed; the current user session and watcher were not reloaded or toggled.
