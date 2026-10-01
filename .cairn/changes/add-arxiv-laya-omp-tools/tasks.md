## Phase 1: Implementation

- [x] [serial] Package the complete metadata index and selective verified paper-text reader. r[onix.arxiv-corpus.search] r[onix.arxiv-corpus.read]
- [x] [serial] Package real pinned CPU Laya inference with explicit language and calibration limits. r[onix.laya.decisions]
- [x] [serial] Register both native OMP tools and declare private service placement. r[onix.research-tools.omp] r[onix.research-tools.private-deployment]

## Phase 2: Deployment and verification

- [x] [serial] Deploy only the selected Aspen2 services and install the generated OMP extension. r[onix.research-tools.private-deployment]
- [x] [serial] Exercise full-corpus search, verified paged reads and real typed predictions through OMP. r[onix.arxiv-corpus.search] r[onix.arxiv-corpus.read] r[onix.laya.decisions] r[onix.research-tools.omp]
- [x] [serial] Record private binding, protected service identities and native lifecycle validation. r[onix.research-tools.private-deployment]

## Phase 3: Mesh-LLM integration

- [x] [serial] Implement native research operation manifests and encrypted peer-stream forwarding. r[onix.research-tools.mesh]
- [x] [serial] Restore Aspen2's current private Mesh binding without restarting inference backends. r[onix.research-tools.mesh]
- [x] [serial] Route the existing OMP tools through a research-only private Mesh ingress. r[onix.research-tools.mesh]
- [x] [serial] Verify cross-peer HTTP and MCP results, errors, private ingress, and stable protected service identities; record Aspen2 Qwen's pre-existing automatic restart loop separately. r[onix.research-tools.mesh]

## Phase 4: Additional Aspen3 Laya provider

- [x] [serial] Permit native Mesh providers to expose only their configured research backends, rejecting an empty provider. r[onix.research-tools.mesh]
- [x] [serial] Deploy the same pinned CPU Laya checkpoint on Aspen3 with dedicated persistent state and private networking. r[onix.laya.decisions] r[onix.research-tools.private-deployment]
- [x] [serial] Verify Aspen3's real predictions, Laya-only MCP discovery, rejected corpus routes, and unchanged Aspen2/default routing and protected services. r[onix.research-tools.mesh]

## Phase 5: Native Vulkan provider on Aspen1

- [x] [parallel] Package the pinned laya.cpp source, submodules and English checkpoint with a bounded resident Vulkan adapter. r[onix.laya.decisions]
- [x] [parallel] Declare GPU-specific sandboxing and Aspen1's Laya-only Mesh research provider while preserving existing routes. r[onix.research-tools.private-deployment] r[onix.research-tools.mesh]
- [x] [serial] Build and activate only the native Laya unit and Aspen1 Mesh sidecar; preserve protected service identities and peer state. r[onix.research-tools.private-deployment]
- [x] [serial] Verify private listeners, actual Vulkan provenance, all three heads, invalid requests, cross-peer Mesh discovery/calls and restart persistence. r[onix.laya.decisions] r[onix.research-tools.mesh]

## Phase 6: Opt-in stuck-loop advisory

- [x] [parallel] Implement the bounded, cancellable, notes-only helper and deterministic asynchronous regressions. r[onix.research-tools.laya-watch]
- [x] [parallel] Package the helper with the existing Mac and desktop extensions without changing inference routes. r[onix.research-tools.laya-watch]
- [x] [serial] Exercise actual OMP commands/tools, live looping/productive backend replays, deadlines and lifecycle boundaries; record observed evidence and validate native Cairn records. r[onix.research-tools.laya-watch]

## Phase 7: Opt-in arXiv relevance reranking

- [x] [parallel] Implement the shared immutable reranker with fixed relevance rubric, bounded classifier copies, serial combined deadline, provenance/token validation, stable ties, original-order fallback and propagated cancellation. r[onix.research-tools.arxiv-rerank]
- [x] [parallel] Extend only the two OMP registrations with search-only `rerank_query`, preserve baseline requests and existing routes, package the same helper beside both entrypoints, and retain raw HTTP/MCP schemas and watcher behavior. r[onix.research-tools.arxiv-rerank]
- [x] [serial] Exercise actual OMP baseline, successful reranking, invalid opt-in, fallback, token-limit and cancellation paths; compare held-out lexical/relevance ordering with the fixed rubric before any default-on decision and record observed quality and latency. r[onix.research-tools.arxiv-rerank]
- [x] [serial] Deploy only the managed client extension, preserve existing services/routing and prior evidence, record scoped proof, and validate native Cairn records using `/home/brittonr/git/OnixResearch/cairn` and its `cairn-policy/generated/cairn-policy.json`. r[onix.research-tools.arxiv-rerank]

## Phase 8: Opt-in arXiv multi-query retrieval

- [x] [parallel] Integrate the shared bounded multi-query helper with exact-distinct Unicode query validation, even total-budget allocation, parallel retrieval, immutable round-robin deduplication and complete per-query provenance; reject malformed, over-quota or drifting replies and cancel siblings on errors or caller cancellation. r[onix.research-tools.arxiv-multi-query]
- [x] [parallel] Extend only both OMP registrations and declarative packages, parse callback replies with SDK passthrough schemas, preserve single-query execution/results and raw service schemas, and select merged baseline positions for optional existing Laya reranking without changing routes or watcher behavior. r[onix.research-tools.arxiv-multi-query]
- [x] [serial] Exercise actual OMP multi-query retrieval and rerank success/fallback on both clients; verify bounds before I/O, budget allocation, every duplicate occurrence, metadata preservation, empty results, quota/provenance errors, sibling cancellation and unchanged legacy behavior. r[onix.research-tools.arxiv-multi-query]
- [x] [serial] Freeze held-out information needs, complementary queries and known primary-paper targets; verify target identities against official metadata and compare original-query, same-expansion OR and multi-query recall at equal total budgets, retaining overlap, missing targets, regressions and latency, with optional reranking checks reported separately and no unsupported corpus-wide recall claim. r[onix.research-tools.arxiv-multi-query]
- [x] [serial] Deploy only the managed client extension through the existing dedicated profile without reloading the current OMP session or changing watcher activation; preserve prior tasks/evidence and record new observed proof before native Cairn validation with `/home/brittonr/git/OnixResearch/cairn` and its `cairn-policy/generated/cairn-policy.json`. r[onix.research-tools.arxiv-multi-query]

## Phase 9: Caller-labeled Laya question evaluation

- [x] [parallel] Implement the canonical shared evaluator and operation schema: validate all 2–8 caller-labeled examples before prediction, omit IDs/expected answers from requests, enforce typed probability/legend/provenance/token-budget invariants, preserve complete replies, compute honest metrics and token-limit warnings, and propagate exact cancellation under one serial 15-second deadline without partial results or retries. r[onix.research-tools.laya-evaluate]
- [x] [parallel] Register native read-only `laya_evaluate` in both entrypoints using SDK passthrough response parsing and package the byte-identical helper beside existing helpers; retain all prior tools, shared operation manifests, routes, services, model settings and watcher behavior. r[onix.research-tools.laya-evaluate]
- [x] [serial] Exercise fresh actual OMP sessions on both clients for choice, score and noul, caller-labeled metrics and matching text/details; verify pre-I/O validation, metadata preservation, malformed probabilities/legends, model and token-budget drift, token-limit equality/overflow, combined deadline and exact caller cancellation including an uncooperative callback. Record observed outcomes without calibration, generalization or authorization claims. r[onix.research-tools.laya-evaluate]
- [x] [serial] Deploy only the managed client extension through existing scoped client packaging/profile mechanisms without reloading the current user session or changing watcher activation, services or routing; append observed deployment/native evidence while preserving every prior phase and outcome, then validate Cairn records using `/home/brittonr/git/OnixResearch/cairn` and its `cairn-policy/generated/cairn-policy.json`. r[onix.research-tools.laya-evaluate]

## Phase 10: Paired caller-labeled question comparisons

- [x] [serial] Extend the canonical evaluator and its existing operation schema with optional compatible baseline questions, complete pre-I/O validation, baseline/candidate interleaving, shared deadline/cancellation/provenance, preserved results, signed metric deltas, paired loss changes, and explicit semantic/significance limitations; retain the default single-question path. r[onix.research-tools.laya-paired-evaluation]
- [x] [serial] Keep behavioral regressions for accuracy/loss tradeoffs, rounded multiclass loss and label-order ties, fractional score losses, invalid label spaces before inference, within-pair drift/failure, shared deadline, and exact cancellation after baseline completion; run the existing regression suite. r[onix.research-tools.laya-paired-evaluation]
- [x] [serial] Exercise actual native OMP handlers and SDK response parsing on Mac and desktop, independently recompute all paired metrics, verify ordering and no expected-label forwarding, preserve metadata and token-limit cases, reject malformed candidate responses and incompatible inputs, and check legacy behavior without quality/generalization claims. r[onix.research-tools.laya-paired-evaluation]
- [x] [serial] Deploy only the byte-identical shared helper through the existing scoped client packaging/profile, leave current session/watcher/routes/services untouched, preserve every prior evidence section, remove isolated proof artifacts, and validate the completed Cairn records with the native generated policy. r[onix.research-tools.laya-paired-evaluation]

## Phase 11: Native unlabeled Laya batch classification

- [x] [parallel] Implement canonical `laya-batch.ts` using the settled shared question/item validators and prediction iterator: validate all 1–16 unlabeled items before I/O, retain ordered full responses/timing/token-limit flags and count, report only the noul threshold, state honest limitations, and return no expected labels, fabricated metrics, retries or partial results. Add meaningful bounds, all-input validation, type/threshold and later-failure/cancellation regressions without claiming they have run. r[onix.research-tools.laya-batch]
- [x] [parallel] Update both native entrypoints to instantiate the shared SDK response factory once for evaluation and batch, register read-only native `laya_batch` through each existing route, and declare both `laya-predict.ts` and `laya-batch.ts` in existing managed packaging without changing raw manifests, services, routes, model settings or watcher behavior. Update these existing contracts while preserving all previous phases and outcomes. r[onix.research-tools.laya-batch]
- [x] [serial] Main: integrate the shared-core extraction and evaluator migration, mirror all canonical helpers to desktop, review compatibility of both evaluation modes and passthrough response parsing, then run formatting, the scoped package build and behavioral regressions including iterator early-exit cleanup. r[onix.research-tools.laya-batch] r[onix.research-tools.laya-evaluate] r[onix.research-tools.laya-paired-evaluation]
- [x] [serial] Main: exercise fresh actual native OMP handlers and SDK parsing on Mac and desktop for all three batch heads, ordered metadata-preserving results, pre-I/O bounds, token-limit equality/overflow, distribution/provenance rejection, shared deadline and exact cancellation; verify matching text/details and unchanged evaluation, legacy tools and watcher behavior. Record observed behavior without quality/calibration/authorization claims. r[onix.research-tools.laya-batch]
- [x] [serial] Main: deploy only the managed client extension through existing scoped mechanisms without reloading the current user session or changing watcher activation, routes or services; append observed verification/deployment evidence without replacing prior outcomes, remove isolated proof artifacts, and validate Cairn records with `/home/brittonr/git/OnixResearch/cairn` and its generated native policy. r[onix.research-tools.laya-batch]

## Phase 12: Five native advisory tools

- [x] [parallel] Build failure triage with bounded original log spans, advisory diagnostic lanes and caller-declared ordered runbook matching. Validate all nested inputs before one shared sequence and retain full prediction metadata. Add meaningful association, bound, failure and cancellation regressions. r[onix.research-tools.laya-failure-triage]
- [x] [parallel] Build independent four-area diff triage, preserving referenced hunks and fractional scores with separate stable review ordering under one deadline. Add boundary, ordering, identity and cancellation regressions. r[onix.research-tools.laya-diff-triage]
- [x] [parallel] Build duplicate checking with coherent endpoint identities, self/reversed-pair rejection, collision-safe keys, retained distinct pairs and flagged-result review selection. Never merge, discard or cluster. r[onix.research-tools.laya-duplicate-check]
- [x] [parallel] Build excerpt evidence matching with independent ID namespaces, coherent citations, directed-pair uniqueness and preserved non-support/flagged-support review targets. Never fetch sources or infer global truth. r[onix.research-tools.laya-evidence-match]
- [x] [parallel] Build completion checking with deterministic missing evidence, ordered inferred rows, zero-call all-empty behavior and review flags without completion authorization. Fix and retain the settling-cancellation regression. r[onix.research-tools.laya-completion-check]
- [x] [serial] Integrate shared reference/ID primitives, both native entrypoints and managed helper declarations, preserving existing schemas/routes. Format sources and pass all 201 extension tests across 14 files with 953 assertions. r[onix.research-tools.laya-failure-triage] r[onix.research-tools.laya-diff-triage] r[onix.research-tools.laya-duplicate-check] r[onix.research-tools.laya-evidence-match] r[onix.research-tools.laya-completion-check]
- [x] [serial] Build and install co-located extension packages on both clients, fixing the reproduced Mac individual-store-file sibling-import failure without full host activation, service changes or current-user-session reload. r[onix.research-tools.laya-failure-triage] r[onix.research-tools.laya-diff-triage] r[onix.research-tools.laya-duplicate-check] r[onix.research-tools.laya-evidence-match] r[onix.research-tools.laya-completion-check]
- [x] [serial] Pass actual native OMP proof for all five tools on both clients, including each 16-prediction maximum, retained token-limit results, 44 pre-I/O invalid inputs, 47 injected failure modes per client, deadlines/cancellation, identity collisions and zero-inference completion. Re-exercise raw, batch, unpaired and paired tools without classifier-quality claims. r[onix.research-tools.laya-failure-triage] r[onix.research-tools.laya-diff-triage] r[onix.research-tools.laya-duplicate-check] r[onix.research-tools.laya-evidence-match] r[onix.research-tools.laya-completion-check]
- [x] [serial] Append complete new evidence through a referenced JSON artifact while preserving the previous 36 verification sections, remove owned isolated proof artifacts, and validate the final records with native Cairn and its explicit generated policy. Do not treat structural validation as review/release/sync/archive approval. r[onix.research-tools.laya-failure-triage] r[onix.research-tools.laya-diff-triage] r[onix.research-tools.laya-duplicate-check] r[onix.research-tools.laya-evidence-match] r[onix.research-tools.laya-completion-check]

## Phase 13: Five additional workflow advisory tools

- [x] [parallel] Implement cited task-context ranking that preserves every excerpt and separates stable fractional context_order from original result order. Add only meaningful behavioral regressions. r[onix.research-tools.laya-context-rank]
- [x] [parallel] Implement test relevance with strict required booleans, independent required_ids and no execution or skip permission. Add only meaningful behavioral regressions. r[onix.research-tools.laya-test-relevance]
- [x] [parallel] Implement described issue-responsibility matching with explicit ambiguity, including token-flagged negative candidates, and no assignment. Add only meaningful behavioral regressions. r[onix.research-tools.laya-issue-route]
- [x] [parallel] Implement independent review-comment classification and priority with two ordered heads, per-prediction token counts and no comment dismissal. Add only meaningful behavioral regressions. r[onix.research-tools.laya-review-triage]
- [x] [parallel] Implement requirement conflict checking with coherent collision-safe unordered pairs, uncertainty review flags and no rewriting/global verdict. Add only meaningful behavioral regressions. r[onix.research-tools.laya-requirement-conflict]
- [x] [serial] Register all five native read-only tools on both clients through existing shared parsing/prediction routes; extend co-located packages and preserve concurrent unrelated module edits. r[onix.research-tools.laya-context-rank] r[onix.research-tools.laya-test-relevance] r[onix.research-tools.laya-issue-route] r[onix.research-tools.laya-review-triage] r[onix.research-tools.laya-requirement-conflict]
- [x] [serial] Run formatting and the complete extension regression suite, build scoped client packages and verify canonical helper parity without changing services, routes or current-session watcher state. r[onix.research-tools.laya-context-rank] r[onix.research-tools.laya-test-relevance] r[onix.research-tools.laya-issue-route] r[onix.research-tools.laya-review-triage] r[onix.research-tools.laya-requirement-conflict]
- [x] [serial] Exercise actual native handlers on both clients for all five tools, upper bounds, original references, ordering/aggregation, token flags, malformed replies, shared deadlines and exact cancellation; re-exercise existing tools without classifier-quality claims. r[onix.research-tools.laya-context-rank] r[onix.research-tools.laya-test-relevance] r[onix.research-tools.laya-issue-route] r[onix.research-tools.laya-review-triage] r[onix.research-tools.laya-requirement-conflict]
- [x] [serial] Retain complete native results in split client artifacts and a checksum-linked manifest, preserve all 37 prior master sections and prior advisory bytes, remove owned proof drivers, and validate native Cairn records without synchronizing or archiving. r[onix.research-tools.laya-context-rank] r[onix.research-tools.laya-test-relevance] r[onix.research-tools.laya-issue-route] r[onix.research-tools.laya-review-triage] r[onix.research-tools.laya-requirement-conflict]
