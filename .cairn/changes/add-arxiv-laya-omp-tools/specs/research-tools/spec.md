## ADDED Requirements

### Requirement: Complete snapshot search

r[onix.arxiv-corpus.search] The corpus service MUST index all metadata shards of the pinned dataset revision, publish the index atomically and return lexical search results with paper identity, citation and license provenance.

#### Scenario: Search the complete snapshot

r[onix.arxiv-corpus.search.complete]
- GIVEN the pinned arXiv Complete metadata has been prepared
- WHEN a client searches a paper title
- THEN results identify matching papers and the immutable snapshot
- AND readiness reports the complete imported metadata row count, not the sample count

### Requirement: Selective verified text retrieval

r[onix.arxiv-corpus.read] The service MUST retrieve only the selected paper-text row group, verify the published text digest, paginate text and distinguish absent text from retrieval failure.

#### Scenario: Read successive text pages

r[onix.arxiv-corpus.read.pages]
- GIVEN a paper with assembled text in the pinned snapshot
- WHEN a client reads consecutive character pages
- THEN pages identify the same paper and digest without overlap or omission
- AND a transport or integrity failure is an error, not an absent-text result

### Requirement: Real typed decisions

r[onix.laya.decisions] Laya MUST run the pinned English root checkpoint using local assets and return actual choice, score and noul predictions with checkpoint and calibration limits. Aspen2 and Aspen3 use the reviewed CPU SDK; Aspen1 uses the pinned laya.cpp runtime on Vulkan with compensated FP32 projections and no CPU or reduced-precision fallback.

#### Scenario: Typed request against a loaded checkpoint

r[onix.laya.decisions.predict]
- GIVEN the pinned model and reviewed runtime have loaded successfully
- WHEN a client submits valid typed questions about an English state
- THEN the response contains actual typed model answers and probabilities
- AND the response identifies the model revision, reviewed SDK or native runtime, actual device and context/calibration limits

### Requirement: Native OMP access

r[onix.research-tools.omp] OMP MUST expose corpus search/read and Laya decisions as discoverable native read-only tools using the deployed services, with cancellation, bounded responses and visible service errors.

#### Scenario: Tool invocation reaches the service

r[onix.research-tools.omp.invoke]
- GIVEN a fresh OMP session loads the managed extension
- WHEN either registered tool is invoked
- THEN it returns the deployed service's real result or error without a mock or silent fallback
- AND existing default-model and Mesh discovery configuration remains unchanged

### Requirement: Private isolated deployment

r[onix.research-tools.private-deployment] Research services MUST use persistent dedicated state and loopback or Tailscale listeners, without deployment-triggered restarts of unrelated inference or application services. Aspen2's corpus and Aspen2/Aspen3 Laya remain CPU-only; Aspen1's native Laya receives only the DRM device access required for Vulkan.

#### Scenario: Scoped service activation

r[onix.research-tools.private-deployment.activate]
- GIVEN the Onix inventory selects the research hosts and private endpoint addresses
- WHEN the selected service units are activated
- THEN the selected endpoints become usable through the private research interface
- AND no public listener is introduced; GPU access is limited to the explicitly selected native backend
- AND no deployment-triggered restart of unrelated services occurs; stable baseline invocation identities remain unchanged

### Requirement: Native Mesh research capabilities

r[onix.research-tools.mesh] The existing corpus and Laya services MUST be exposed as typed Mesh-LLM operations and forwarded between the desktop and Aspen2 over the authenticated Mesh transport. OMP MUST use the Mesh research route without a direct-backend fallback. General management endpoints and join credentials MUST remain unexposed.

#### Scenario: Research request traverses the mesh

r[onix.research-tools.mesh.forward]
- GIVEN Aspen2's provider and the desktop's forwarding plugin share the declared research channel
- WHEN a client invokes corpus retrieval or a Laya decision through the desktop Mesh API
- THEN the actual Aspen2 service result and original HTTP error semantics reach the client
- AND both operations are discoverable through native MCP without fake chat model aliases
- AND unrelated inference services and existing provider declarations remain unchanged

#### Scenario: Additional Laya-only provider

r[onix.research-tools.mesh.laya-aspen3]
- GIVEN Aspen2's existing research services and default desktop route remain running
- WHEN Aspen3's pinned CPU Laya service and native research provider are activated
- THEN real typed decisions are available through Aspen3's private API and native Mesh MCP operation
- AND Aspen3 advertises no corpus operation or corpus HTTP binding
- AND disabled-backend requests and a provider with no configured backends are rejected
- AND the existing default route, Aspen2's services, and Aspen3's unrelated application services are preserved

#### Scenario: Compensated Vulkan provider on Aspen1

r[onix.research-tools.mesh.laya-aspen1]
- GIVEN the tested native source, submodules and English checkpoint are pinned
- WHEN Aspen1's Vulkan service and research plugin are activated
- THEN `research.laya_decide` returns real choice, score and noul answers through the private mesh
- AND provenance identifies laya.cpp, its source commit, the actual Vulkan backend and compensated FP32 precision
- AND the HTTP listener is ready only after a real GPU warmup; missing GPU or native worker failure never falls back to CPU
- AND bounded requests retain the existing decision response/error contract
- AND Aspen1 advertises no corpus capability or fake chat-model alias
- AND its protected inference services, other research providers, desktop default route and Mac's local MLX route remain unchanged

### Requirement: Opt-in nonblocking stuck-loop advice

r[onix.research-tools.laya-watch] The managed OMP extension MUST offer session-local, default-off stuck-loop advice using bounded recent tool observations and the existing private Laya endpoint. It MUST preserve all tool results, existing messages, permissions and completion decisions, and MUST NOT block execution, retry tools or create autonomous agent turns.

#### Scenario: Bounded prior-window advice

- GIVEN the user enables `/laya-watch on` and at least three new supported tool results exist
- WHEN a valid nontruncated noul judgment suggests repetition
- THEN the user receives at most one uncalibrated advisory per prompt
- AND the next naturally occurring model request may receive the fixed prior-window note without modifying existing context
- AND successful mutations remain evidence of change while raw file/patch payloads, images, environment maps and detail blobs are excluded

#### Scenario: Inactive, stale or unavailable advice

- GIVEN monitoring is off, a session changes, newer observations arrive during inference, or the service fails
- WHEN a classification would be stale, unavailable, malformed or at the token limit
- THEN no stale or invalid advice is delivered and no additional turn or retry is started
- AND requests have a three-second deadline, with unavailable-service errors reported at most once per prompt
- AND new sessions and navigation never inherit activation

### Requirement: Opt-in immutable arXiv relevance reranking

r[onix.research-tools.arxiv-rerank] The managed OMP `arxiv_corpus` tool MUST offer optional search-only `rerank_query` without changing the raw corpus HTTP or Mesh/MCP operation schemas. It MUST retain the lexical `query`, preserve every original result and field including numeric BM25 `rank`, citations, licenses and dataset provenance, and never mutate the input response. Without opt-in, execution and response MUST remain unchanged. The two clients MUST share the same reranker and retain their existing retrieval/inference routes, paper reads, typed decisions and stuck-loop watcher.

#### Scenario: Distinct lexical retrieval and relevance intent

- GIVEN a search has a valid lexical `query` and a nonblank 1–500-character `rerank_query`
- WHEN all candidates receive valid scores from the fixed four-level relevance question within one serial 15-second scoring deadline after search
- THEN all candidates are returned by descending score with exact ties retaining their original position
- AND each copied result adds `laya_score`, 1-based `bm25_position` and `laya_input_truncated`, without changing its original `rank` or full title/snippet
- AND matching text/details include applied rerank metadata identifying the relevance query, [0,3] score range, fixed criteria, model/revision and available runtime/device/SDK/dtype provenance, plus title/snippet input limits of 240/600 UTF-16 code units
- AND no inference batch, new transport, service, route or model-setting change is introduced

#### Scenario: Invalid opt-in fails before retrieval

- GIVEN `rerank_query` is supplied for read, is blank, is not a string or exceeds 500 characters
- WHEN the OMP tool executes
- THEN it visibly rejects the invalid option before making a retrieval request
- AND neither the raw corpus HTTP API nor Mesh/MCP discovery advertises this client-only option

#### Scenario: Bounded inputs and complete original-order fallback

- GIVEN classifier-only title/snippet copies are limited to 240/600 UTF-16 code units without truncating the relevance query or returned originals
- WHEN a response has invalid candidate shape, more than 20 candidates, an inference error/deadline, missing or inconsistent provenance, a nonfinite/out-of-range score, or `usage.input_tokens >= 512`
- THEN the original results, order and fields are returned without any partial scoring annotations
- AND rerank metadata reports `status: fallback`, the relevance query and a visible concise reason
- AND an empty result set instead skips inference with `status: skipped` and `reason: no_results`

#### Scenario: Cancellation and relevance evidence remain distinct

- GIVEN caller cancellation occurs before or during scoring
- WHEN reranking settles
- THEN cancellation propagates and never masquerades as successful fallback
- AND any default-on decision requires a recorded held-out comparison of lexical and reranked relevance, ordering regressions, latency and fallback frequency with the question/rubric held fixed
- AND uncalibrated scores are not represented as relevance guarantees or permission decisions

### Requirement: Opt-in bounded arXiv multi-query retrieval

r[onix.research-tools.arxiv-multi-query] The managed OMP `arxiv_corpus` tool MUST offer search-only `queries` as an opt-in alternative to `query`, accepting 2–4 complementary nonblank, exact-distinct expressions supplied by the main model, each at most 500 Unicode code points. It MUST share one bounded candidate budget, deduplicate by paper ID using a deterministic round-robin merge, preserve every query-specific occurrence and all original provenance, and optionally apply the existing Laya reranker. It MUST NOT generate queries, hardcode paper IDs, change raw corpus HTTP or Mesh/MCP schemas, or alter existing single-query execution/results, reads, endpoints, services, inference routes or watcher behavior.

#### Scenario: Reject invalid multi-query arguments before retrieval

- GIVEN `queries` is present on a read, is supplied with `query`, is not a 2–4-element array, contains blank/nonstring/overlong or exact-duplicate strings, or has an invalid total budget
- WHEN the managed OMP tool executes
- THEN it rejects the request before any retrieval or inference I/O
- AND the multi-query budget defaults to 10 and otherwise MUST be an integer at most 20 and at least the query count
- AND the registration's array items reuse the original query schema with a nonblank pattern, and expose the total-budget limits

#### Scenario: Allocate a fixed budget across complementary queries

- GIVEN valid `queries`, optional category and a valid total budget
- WHEN retrieval begins
- THEN each query receives the integer floor of budget divided by query count, with remainder slots assigned to earlier queries
- AND the requests run in parallel through the existing corpus route with no retries, refill, automatic query generation, silent result slicing or partial-success response
- AND the original category is applied consistently to every request

#### Scenario: Merge immutable results with complete provenance

- GIVEN all query replies have matching nonblank dataset/revision and positive integer schema version, valid result fields and counts within their assigned quotas
- WHEN the helper merges results by original result position and then query order
- THEN paper IDs are unique in the merged results and absolute BM25 scores are never compared between queries
- AND the first occurrence preserves every original paper field, numeric `rank` and snippet without mutating inputs
- AND each unique result adds its 1-based merged `retrieval_position` plus every occurrence in `retrieval_sources`, each containing 0-based `query_index`, 1-based query-local `bm25_position`, original `rank` and query-specific `snippet`
- AND passthrough SDK schemas preserve unknown top-level and paper fields while requiring nonblank paper ID/title, string snippet and finite numeric rank
- AND the response retains first-query reply metadata excluding `results` and `query`/`limit`/`category` echoes, with `retrieval.mode: multi_query`, `merge_order: round_robin`, total budget, fetched and unique counts
- AND `retrieval.queries` retains each query, allocated limit, returned count and all original per-query top-level metadata except results, including echoes and unknown provenance
- AND empty or overlapping query results do not trigger refill, and JSON text and structured details describe exactly the same merged response even without reranking

#### Scenario: Fail the whole retrieval and cancel siblings

- GIVEN a query fails, returns a malformed reply or too many candidates, or disagrees on dataset/revision/schema version
- WHEN that failure is observed
- THEN all sibling requests are cancelled and the whole multi-query retrieval fails without a partial response
- AND caller cancellation before or during retrieval cancels siblings and propagates the caller's reason rather than returning success or rerank fallback

#### Scenario: Rerank the merged candidate set without inventing global BM25 order

- GIVEN a valid search uses `queries` and optional search-only `rerank_query`
- WHEN existing Laya scoring succeeds using the fixed rubric, current client route and combined 15-second scoring deadline
- THEN all unique results preserve their original fields and per-query sources, adding scores while retaining merged-baseline `retrieval_position` rather than adding a global `bm25_position`
- AND exact score ties retain merged input order
- AND scoring failure returns the complete merged response and order unchanged except existing visible rerank metadata, while caller cancellation propagates
- AND omitted `queries` preserves legacy single-query execution/results and existing four-argument reranker behavior

#### Scenario: Held-out recall acceptance is separate from ranking correctness

- GIVEN held-out information needs, complementary query lists and known primary-paper targets were frozen before evaluation, with target identities verified against primary metadata and IDs used only for scoring, never retrieval
- WHEN original-query, same-expansion single-OR and multi-query retrieval are compared at equal total candidate budgets
- THEN any claimed known-paper recall improvement is supported by observed target coverage with per-case overlap, duplicates, missing targets, regressions and latency retained in the evidence
- AND optional reranking quality, latency and fallback frequency are reported separately from retrieval coverage
- AND preselected-target recall is not represented as blinded relevance of all candidates, exhaustive corpus-wide recall, calibrated guarantees or permission for default-on behavior
- AND implementation verification and scoped deployment require observed evidence, without replacing prior completed tasks or evidence

### Requirement: Bounded caller-labeled Laya question evaluation

r[onix.research-tools.laya-evaluate] The managed OMP extension MUST expose native read-only `laya_evaluate` for one caller-supplied choice, score or noul question against 2–8 caller-labeled examples. It MUST validate all input before inference, preserve full parsed predictions and provenance, report complete ordered results and appropriate metrics with explicit limitations, and fail the entire evaluation on errors, deadline, cancellation or model/token-budget drift. It MUST NOT generate labels, tune questions, send expected answers or example IDs to inference, silently truncate input, retry, return partial metrics, or alter existing tools, raw operation manifests, services, endpoints, routing, model settings or watcher activation.

#### Scenario: Validate the complete caller-labeled evaluation before inference

- GIVEN one question and an array of examples containing `{id, state, expected}`
- WHEN any example or the question is invalid
- THEN no prediction request is made
- AND valid inputs require 2–8 examples with exact-unique nonblank IDs of 1–64 Unicode code points, string or nonnull nonarray object states, and nonblank instructions of at most 1000 code points
- AND question criteria follow existing service constraints: 2–20 choice labels or ordered score levels, nonblank labels/descriptions of at most 500 code points, distinct array entries, and absent noul criteria or exactly `false`/`true` descriptions
- AND choice expectations are declared string labels, score expectations are integer level indices in `[0,k-1]`, and noul expectations are booleans
- AND the native operation reuses existing `laya_decide` state/question schemas without modifying `operations.json` or the existing 32 KiB server request-body bound

#### Scenario: Evaluate serially through the existing client route

- GIVEN every example and the single question passed validation and no `baseline_question` is supplied
- WHEN native `laya_evaluate` executes
- THEN it submits one `/predict` request per example in input order with only `{state, questions: {evaluation: question}}`
- AND the Mac uses its existing local MLX callback while desktop uses its existing Mesh callback
- AND one combined 15-second deadline governs the entire serial prediction sequence
- AND a failed prediction, parse, invariant check, deadline or identity comparison fails the entire operation with no retries, fallback or partial metrics
- AND caller cancellation propagates its exact reason even with an uncooperative callback, and all abort listeners and timers are released

#### Scenario: Parse complete typed predictions without losing unknown metadata

- GIVEN an external prediction reply
- WHEN the entrypoint parses it using the once-instantiated `layaPredictionResponseSchema(pi.zod)` from shared `laya-predict.ts`, reused by evaluation and batch
- THEN nonblank model/revision/device/SDK provenance is required, with optional runtime/dtype/artifact model/artifact revision nonblank when present
- AND positive integer full/head token budgets are required with head strictly below full, while usage requires positive integer input tokens and nonnegative integer output tokens
- AND the answers object contains exactly `evaluation` with the requested discriminated answer type: string choice and probabilities, finite score with probabilities/legend, or noul probability
- AND every numeric probability is finite and within `[0,1]`
- AND unknown root, usage and answer fields survive passthrough parsing and remain in the complete per-example `response`

#### Scenario: Reject malformed distributions and provenance drift

- GIVEN parsed predictions for the caller's question
- WHEN choice/score probability keys differ from the exact declared label or level-index set, mass differs from one by more than `1e-4` per label, or a chosen label is not at the maximum reported probability
- THEN the entire evaluation fails without renormalizing probabilities or producing metrics
- AND exact maximum-probability ties are permitted
- AND score predictions must lie in `[0,k-1]`, have the exact expected level-index/description legend and agree with the probability-weighted level index within `1e-4 * (1 + sum of level indices)`
- AND model, revision, device, SDK version, optional runtime/dtype/artifact identity and both token budgets must remain identical across examples, including optional-field presence
- AND malformed required metric fields cannot be replaced by confidence, generated values or fallback metrics

#### Scenario: Retain token-limit equality with an honest truncation warning

- GIVEN exactly one question was sent for each example
- WHEN a reply's input-token usage exceeds its reported per-question maximum
- THEN the entire evaluation fails
- AND equality is instead retained in the evaluation with per-example `input_token_limit_reached: true` and a summary count
- AND the response explains that equality means possible truncation, while a false flag cannot rule out earlier 192-token question/option truncation
- AND token-limit examples are never silently dropped from aggregate metrics

#### Scenario: Return caller-labeled metrics and complete ordered evidence

- GIVEN every prediction passes parsing, consistency and deadline checks
- WHEN the evaluation completes
- THEN matching JSON text and structured details contain `status: complete`, the question, `label_source: caller_provided`, `examples_evaluated`, ordered results, root `elapsed_ms` and a summary
- AND each result contains the caller's ID and expected value, actual value, complete parsed original `response`, `input_token_limit_reached` and `elapsed_ms`
- AND choice actuals use the reported label, score actuals use the reported weighted level index rather than an argmax bucket, and noul actuals use `p >= 0.5` with ties true and explicit `decision_threshold: 0.5` metadata
- AND choice/noul summaries report accuracy and mean Brier score, plus the count of input-token-limit examples
- AND choice Brier uses the unnormalized sum of squared probability minus one-hot-label differences, with nominal range `[0,2]` for normalized distributions and reported rounded values used without normalization or clipping, while noul Brier uses squared probability minus boolean-label difference, with range `[0,1]`
- AND score summaries report mean absolute error between weighted level indices and expected integer levels, plus the count of input-token-limit examples

#### Scenario: Keep limited evaluation separate from calibration and authorization

- GIVEN expected labels are supplied by the caller for only 2–8 examples
- WHEN results or subsequent native verification/deployment evidence are recorded
- THEN the response explicitly states that the configured base checkpoints are English-only, not the separately fine-tuned typed-decisions model, that labels are not independently verified, and that the tiny sample establishes neither calibration nor generalization nor authorization
- AND reported confidence is never conflated with a label probability or treated as a safety guarantee
- AND both declarative packages include the same canonical helper without changing previous registrations, raw HTTP/Mesh/MCP schemas or watcher activation
- AND fresh native behavior and scoped client deployment require observed evidence, preserving all prior phases and outcomes rather than treating declaration or packaging as verified deployment

### Requirement: Paired caller-labeled question comparisons

r[onix.research-tools.laya-paired-evaluation] Native OMP `laya_evaluate` MUST accept optional `baseline_question` to compare the main candidate question with a caller-supplied baseline on the same examples. It MUST validate comparability before inference, retain complete results for both variants, report signed metric and per-example loss differences, and preserve the existing no-baseline behavior. It MUST NOT generate labels, tune questions, select an automatic winner, infer statistical significance, retry failures, or return partial metrics.

#### Scenario: Validate compatible question and label spaces before any prediction

- GIVEN a candidate question, optional baseline question, and 2–8 caller-labeled examples
- WHEN a baseline is supplied
- THEN both questions and every example are validated before any inference
- AND types must match and choice labels must form the same exact set, permitting reordered labels, array/object representation changes, and changed descriptions
- AND score levels must be identical in the same order, not merely the same count, while noul criteria retain the existing false/true rules
- AND malformed baselines, incompatible label spaces, or invalid expected answers cause zero prediction requests

#### Scenario: Interleave paired requests under one budget and provenance identity

- GIVEN all comparison inputs are valid
- WHEN each example is evaluated
- THEN one baseline request precedes one candidate request, in input example order, with only state and the selected question under the existing evaluation key
- AND expected answers and IDs remain client-side, with at most 16 single-question predictions
- AND all predictions share one existing 15-second deadline, exact caller cancellation, and one model/runtime/artifact/token-budget identity
- AND drift within a pair or across examples, malformed replies, transport failure, deadline, or cancellation fails the entire comparison without retries or partial results

#### Scenario: Preserve candidate and baseline evidence without changing example counts

- GIVEN every paired prediction succeeds
- WHEN the complete result is returned
- THEN existing root question, results, summary and examples_evaluated describe the candidate and shared example count
- AND comparison.baseline contains its question, complete ordered results and summary, with original prediction metadata and per-prediction elapsed time/token-limit flags
- AND root elapsed_ms covers the entire operation and the 0.5 noul threshold, with ties true, applies to both questions
- AND JSON text and structured details describe the identical result

#### Scenario: Report signed metrics and per-example losses without a winner

- GIVEN complete results for both variants
- WHEN comparison metrics are calculated
- THEN delta_direction is candidate_minus_baseline and each delta subtracts baseline from candidate for accuracy, mean Brier score or mean absolute error, and the token-limit count
- AND each pair reports its ID, baseline_loss, candidate_loss and loss_delta
- AND choice loss uses unnormalized multiclass Brier, noul uses binary Brier, and score uses absolute error on the reported weighted level index rather than argmax
- AND reported rounded probabilities are not normalized or clipped, and both choice losses use the same candidate label order
- AND loss_changes counts negative, positive and exactly-zero paired deltas as improved, regressed and tied
- AND accuracy gains may coexist with worse Brier loss without producing an automatic winner

#### Scenario: Keep token-saturated predictions in both variants

- GIVEN separate single-question predictions expose independent input-token usage
- WHEN either variant reaches its reported context limit
- THEN that prediction remains in all metrics and is visibly flagged and counted for its own variant
- AND above-limit usage is rejected, token budgets must remain identical throughout, and false flags cannot rule out earlier head truncation

#### Scenario: Preserve existing consumers and deployment boundaries

- GIVEN no baseline_question is supplied
- WHEN laya_evaluate runs
- THEN it retains one prediction per example, existing candidate results/metrics, and no comparison field
- AND both existing entrypoints and packaging consume the shared helper without a new tool, raw operation, runtime dependency, service, model setting, or route
- AND native legacy search and decision behavior, other native tool schemas, and watcher activation remain unchanged

#### Scenario: Keep paired observations separate from semantic or statistical guarantees

- GIVEN both questions use matching labels and caller-supplied expected answers
- WHEN comparison results or verification evidence are presented
- THEN the response explains that matching labels cannot verify that both questions express the same task
- AND differences describe only the caller-labeled examples, with no inferred winner, statistical significance, calibration, generalization, safety or authorization
- AND all existing English-only checkpoint and independently-unverified-label limitations remain
- AND native observations and scoped deployment evidence are appended without replacing earlier outcomes, reloading the current user session, or changing its watcher state

### Requirement: Native unlabeled Laya batch classification

r[onix.research-tools.laya-batch] The managed OMP extension MUST expose native read-only `laya_batch` for one choice, score or noul question over 1–16 unlabeled items. It MUST reuse the evaluator's extracted SDK parser, question/item validators and serial prediction engine rather than duplicating or weakening validation. It MUST retain complete ordered predictions, provenance, timing and token-limit flags/counts, and fail the whole operation on malformed input, prediction failure, deadline, cancellation or identity drift. It MUST NOT generate gold labels, accuracy or loss metrics, introduce paired questions or threshold knobs, clip text, sort/group items, retry, return partial results, authorize actions, or change raw operation manifests, other native tools, services, routes, model settings or watcher behavior.

#### Scenario: Validate the whole unlabeled batch before I/O

- GIVEN one question and `items` containing `{id, state}` without expected labels
- WHEN the input root, question, item array or any item is invalid
- THEN no prediction request is made
- AND there MUST be 1–16 items with exact-unique nonblank IDs of at most 64 Unicode code points and string or nonnull nonarray object states
- AND the shared question validator retains existing instruction/criteria limits, ordered score labels and absent-or-exact-false/true noul criteria
- AND the operation schema reuses existing `operations.laya_decide` question/state schemas, requires question/items and item id/state, and exposes min1/max16 bounds and nonblank min1/max64 IDs
- AND the existing server request-body limit remains unchanged; no implicit client clipping is introduced

#### Scenario: Share prediction invariants without changing either evaluator mode

- GIVEN evaluation or batch has validated every input before inference
- WHEN it supplies tasks with already-validated labels to `predictLayaSequence`
- THEN the common `laya-predict.ts` engine serializes requests containing only state and `questions.evaluation`, with no item IDs or expected-label metadata sent to inference
- AND one 15-second deadline, cancellation controller and model/runtime/artifact/token-budget identity cover the complete operation, with no deadline reset per item
- AND task iteration does not flatten or copy state arrays
- AND both native entrypoints instantiate one SDK `layaPredictionResponseSchema(pi.zod)` for evaluation and batch, using supported `z.union` and passthrough for unknown root, usage and answer metadata
- AND required/optional provenance, presence consistency, both token budgets, finite [0,1] probabilities, exact probability key sets, mass tolerance `1e-4` per label, maximum-probability choice ties, score bounds/legends/weighted-index agreement and noul validation retain the existing evaluator semantics
- AND the evaluator retains complete expected-label and baseline compatibility validation, baseline-then-candidate ordering, canonical candidate label order for both paired loss sums, both public output modes, existing metrics and every limitation
- AND moved symbols have no aliases or re-exports from the evaluator

#### Scenario: Return complete unlabeled predictions in original order

- GIVEN every item succeeds and the deadline remains valid through sequence completion
- WHEN the native batch operation returns
- THEN JSON text and structured details describe the same object containing exactly status complete, question, items_processed, ordered results, whole-operation elapsed_ms, input_token_limit_reached as a count, limitations, and decision_threshold 0.5 only for noul
- AND every result contains id, actual, the complete parsed original response, a boolean input_token_limit_reached and per-prediction elapsed_ms
- AND choice actuals use the reported label, score actuals preserve the fractional probability-weighted level index instead of an argmax bucket, and noul actuals use p >= 0.5 with ties true
- AND no expected field, label_source, accuracy, Brier loss, MAE, summary metrics or automatic action is fabricated
- AND input order is unchanged and no result is silently dropped

#### Scenario: Retain token-limit equality without inventing quality evidence

- GIVEN exactly one question is sent in each prediction request
- WHEN usage equals its reported per-question maximum
- THEN the prediction remains in the ordered batch, is visibly flagged, and contributes one to the root token-limit count
- AND above-limit usage fails the operation rather than returning an invalid prediction
- AND limitations state that equality indicates possible truncation while false cannot rule out earlier 192-token question/option clipping
- AND limitations identify the configured English-only base checkpoint as distinct from the separately fine-tuned typed-decisions model, state that probabilities are uncalibrated and confidence is not label probability, and deny accuracy, calibration, generalization, safety or authorization inference from unlabeled predictions
- AND complete responses retain original provenance rather than invented aggregate model evidence

#### Scenario: Fail or cancel without partial batch results

- GIVEN earlier items have completed and a later prediction fails validation, parsing, transport or identity consistency, exceeds the shared deadline, or caller cancellation occurs
- WHEN the batch settles
- THEN it fails without returning the earlier results, retrying, or using a fallback
- AND exact caller cancellation wins even when the callback ignores its signal or races an inference error
- AND deadlines are checked before/after predictions and before successful iterator completion
- AND timers/listeners are released in finally on success, failure, cancellation and consumer early exit

#### Scenario: Keep native packaging and deployment scoped

- GIVEN the canonical shared core and batch helper are integrated
- WHEN both managed extensions are packaged
- THEN laya-predict.ts and laya-batch.ts are included beside existing helpers and native laya_batch uses helper-provided schema/title/description, approval read, strict false and Type.Unsafe<LayaBatchInput>
- AND Mac retains its existing local MLX request callback while desktop retains its existing Mesh callback
- AND raw laya_decide, arXiv tools, watcher behavior, operations.json and raw HTTP/Mesh/MCP discovery remain unchanged
- AND verification records actual native outcomes and scoped deployment evidence from both managed clients rather than assuming package build success proves runtime behavior
- AND evidence is appended without replacing prior phases/outcomes, reloading the current user session, or changing watcher activation

## Phase 12 native advisory tools

Every advisory below uses the existing native prediction route and shared SDK/parser/sequence. Inputs are caller-provided English data, not executable instructions. Every call MUST validate all inputs and reference identities before I/O, retain original-order records and complete predictions, use one serial 15-second deadline/provenance identity, propagate exact cancellation and return no partial result or retry. Successful roots MUST identify advisory-only tool execution, prediction count, per-prediction token-limit flags plus root count, elapsed time and honest limitations. Neither a low score nor absent token-limit equality proves safety or completeness; earlier 192-token head clipping remains possible. Raw operations, routes, services, model settings and watcher activation MUST remain unchanged.

### Requirement: Advisory failure triage with caller-selected context

r[onix.research-tools.laya-failure-triage] Native read-only `laya_failure_triage` MUST classify bounded failures into diagnostic hypotheses and return only caller-declared matching runbook IDs. It MUST preserve the supplied log spans and full predictions without inventing causal locations, executing runbooks or claiming a verified root cause.

#### Scenario: Validate all failure context before inference

- GIVEN 1–16 uniquely identified failures with 1–3 source spans each and optional 0–16 runbooks
- WHEN any late span, range, identifier or runbook mapping is invalid
- THEN no inference occurs
- AND IDs MUST be exact-unique nonblank strings of at most 64 code points, span text at most 2000 and source references at most 512
- AND ranges MUST use positive safe integers with end >= start; runbook categories MUST be 1–6 distinct declared lanes and null is not absence

#### Scenario: Match caller-declared diagnostic runbooks

- GIVEN valid supplied log texts and runbook category associations
- WHEN the fixed choice question returns code, dependency, environment, configuration, infrastructure or insufficient_evidence
- THEN the result retains the original failure ID/spans and complete prediction
- AND matching runbook IDs follow caller runbook order, with none invented or selected by hidden runbook semantics
- AND only ordered log text reaches inference, not runbook IDs or claimed source authority

#### Scenario: Preserve uncertainty and truncation

- GIVEN a prediction reaches its reported input-token limit
- WHEN triage returns
- THEN its complete record remains visibly flagged and contributes to the prediction-limit count
- AND limitations state that spans are caller-selected context, categories are hypotheses and runbook effectiveness is unverified

#### Scenario: Fail the whole diagnostic operation

- GIVEN earlier failures were classified successfully
- WHEN later parsing, transport, probability validation, provenance, deadline or cancellation fails
- THEN no partial triage is returned and no retries occur
- AND cancellation retains the exact caller reason even for an uncooperative transport

### Requirement: Independent referenced diff review priorities

r[onix.research-tools.laya-diff-triage] Native read-only `laya_diff_triage` MUST prioritize human review of 1–4 supplied hunks independently for security, API compatibility, concurrency and performance. It MUST preserve paths, old/new sides, ranges, text and full predictions without asserting vulnerability, safety or measured performance.

#### Scenario: Validate complete referenced hunks

- GIVEN hunks have unique IDs, nonblank paths/text and old/new sides
- WHEN any late hunk has invalid text/reference bounds, side or safe positive ordered line range
- THEN no prediction is made
- AND line references remain caller-provided rather than independently verified

#### Scenario: Score independent review areas under one deadline

- GIVEN valid hunks
- WHEN classification runs
- THEN four ordinal predictions occur per hunk in security, api_compatibility, concurrency, performance order
- AND all at most 16 predictions share one deadline and provenance identity, not one per hunk or area
- AND each score preserves its fractional probability-weighted level index on the three-level review scale

#### Scenario: Rank without rearranging original records

- GIVEN all four area predictions completed for every hunk
- WHEN the tool returns
- THEN each hunk priority is the maximum of its four area scores
- AND results remain in input order while a separate review_order sorts IDs descending by priority with input-order ties
- AND no score is rounded into a bucket and no hunk is dropped

#### Scenario: Retain every token-limited area

- GIVEN multiple area predictions reach the token limit for one hunk
- WHEN counts are returned
- THEN every area response remains visible and each flagged prediction contributes separately to the root count
- AND low priorities and unflagged inputs do not establish safety or substitute for human review

#### Scenario: Reject incomplete review output

- GIVEN an earlier area or hunk completed
- WHEN a later request fails, changes provenance, exceeds the deadline or is cancelled
- THEN the entire operation fails without exposing a partial review ordering or resetting its deadline

### Requirement: Reviewable candidate duplicate pairs

r[onix.research-tools.laya-duplicate-check] Native read-only `laya_duplicate_check` MUST classify 1–16 supplied candidate pairs as duplicate, related or distinct, retain all original records and identify advisory review pairs. It MUST NOT merge, discard, generate explanations or infer transitive clusters.

#### Scenario: Enforce coherent endpoint identities

- GIVEN endpoint IDs may recur across pairs
- WHEN any reused ID has different text or a late endpoint is malformed
- THEN the whole input fails before inference
- AND pair IDs and endpoint IDs use bounded nonblank identity rules; endpoint text is at most 2000 code points

#### Scenario: Distinguish unordered pairs without delimiter collisions

- GIVEN pairs A/B and B/A, or a self-pair A/A
- WHEN validation runs
- THEN repeated unordered pairs and self-pairs are rejected even with different pair IDs
- AND distinct IDs containing delimiters remain distinct; pair keys MUST NOT rely on ambiguous string concatenation

#### Scenario: Preserve every pair and flagged distinct judgment

- GIVEN a valid duplicate, related or distinct model judgment
- WHEN results are returned
- THEN every pair retains its original left/right records, identity and full prediction in input order
- AND review_ids includes duplicate/related pairs and every token-limit-flagged pair, including distinct ones

#### Scenario: Avoid stronger duplicate claims

- GIVEN the model reports distinct or labels two separate pairs duplicate
- WHEN a consumer reads the output
- THEN limitations deny proof of nonduplication and automatic or transitive merging/discarding
- AND supplied texts alone reach inference, not metadata presented as authority

#### Scenario: Keep pair checking atomic

- GIVEN earlier pairs completed
- WHEN any later prediction fails or the shared deadline/cancellation/provenance contract is violated
- THEN no partial pair judgments or retries are returned

### Requirement: Cited excerpt and claim matching

r[onix.research-tools.laya-evidence-match] Native read-only `laya_evidence_match` MUST compare 1–16 supplied claim/excerpt pairs as supports, contradicts or insufficient_evidence. It MUST retain citations and full predictions without fetching sources, inferring source authority, aggregating claim truth or acting as a general fact checker.

#### Scenario: Keep claim and evidence identities separate

- GIVEN claim IDs and evidence IDs occupy independent namespaces
- WHEN the same spelling appears in both
- THEN it is valid without requiring identical claim/evidence text
- AND within either namespace repeated IDs MUST preserve their text, and evidence IDs MUST also preserve citation

#### Scenario: Validate directed pair uniqueness

- GIVEN bounded valid claim/evidence records
- WHEN the same claim/evidence pair recurs under another pair ID
- THEN validation rejects it before inference
- AND reversed directed pairs and delimiter-bearing IDs remain distinct when identity content is coherent

#### Scenario: Judge only the supplied excerpt

- GIVEN claim text and one caller-cited excerpt
- WHEN the fixed choice question runs
- THEN it judges direct support, direct contradiction or insufficient evidence from that excerpt only
- AND topic overlap alone is not declared support, citations are not fetched, and no generated explanation or global truth verdict appears

#### Scenario: Preserve citations and uncertain support

- GIVEN all pairs succeed
- WHEN results are returned
- THEN original claims/excerpts/citations and full predictions remain in input order
- AND attention_ids includes non-supporting pairs and token-limit-flagged support without silently dropping any pair

#### Scenario: Reject conflicting references and later failure

- GIVEN earlier valid input or predictions
- WHEN a late citation identity conflicts, validation fails, or prediction/deadline/cancellation/provenance fails
- THEN invalid input makes no inference and inference failure returns no partial matches or retries

### Requirement: Acceptance evidence advisories without completion authorization

r[onix.research-tools.laya-completion-check] Native read-only `laya_completion_check` MUST compare 1–16 supplied acceptance criteria with 0–3 caller-cited observations each. It MUST flag missing/conflicting/insufficient or token-limited evidence while preserving order and full real predictions, without running tests, verifying execution or authorizing task completion/stopping.

#### Scenario: Validate every criterion and evidence identity first

- GIVEN bounded uniquely identified nonblank criteria and per-criterion distinct evidence IDs
- WHEN any late observation is malformed or a globally reused evidence ID changes text/citation
- THEN no prediction is made
- AND citations and text retain the same bounded reference semantics as other advisories

#### Scenario: Represent missing observations honestly

- GIVEN a criterion has no supplied observations
- WHEN the checker processes it
- THEN assessment is deterministically missing_evidence, prediction is null and no model call is made for that criterion
- AND missing rows before, between and after inferred rows remain in original criterion order

#### Scenario: Handle an all-empty evidence set

- GIVEN every criterion has empty evidence
- WHEN the checker runs
- THEN zero predictions are reported and every criterion is listed for review
- AND cancellation while the zero-inference result is settling still rejects with the exact caller reason rather than returning success

#### Scenario: Classify supplied observations conservatively

- GIVEN a criterion has one or more supplied observations
- WHEN the fixed choice question runs
- THEN it returns supported, conflicting or insufficient_evidence based only on the provided criterion and evidence texts
- AND original observations/citations/full prediction remain intact
- AND criteria_to_review includes every non-supported or token-limit-flagged criterion

#### Scenario: Preserve one execution contract across gaps

- GIVEN inferred criteria are separated by missing-evidence criteria
- WHEN predictions run
- THEN all use one fully consumed iterator, deadline and provenance identity, with no resets across gaps
- AND later failure or cancellation returns no earlier inferred or deterministic rows as a partial result

#### Scenario: Never turn an advisory into permission to stop

- GIVEN the tool finishes or its review list is empty
- WHEN the output is consumed
- THEN status complete describes only this tool call and advisory_only remains true
- AND no task-complete, ready-to-stop or authorization boolean is produced
- AND limitations deny substitution for tests, verification of execution and proof of acceptance

### Requirement: Cited task context ranking

r[onix.research-tools.laya-context-rank] Native read-only `laya_context_rank` MUST rank 1–16 caller-cited excerpts for relevance to one supplied task using a fixed ordinal score. It MUST preserve every excerpt, original order, references and full predictions, returning a separate stable descending fractional context_order without pruning context or claiming accuracy, authority or sufficiency.

#### Scenario: Preserve association and stable fractional ranking

- GIVEN excerpts have distinct IDs and valid citations
- WHEN independent relevance predictions include fractional values, ties or zero
- THEN results retain every original excerpt in input order
- AND context_order contains every ID in descending relevance with original-order ties

#### Scenario: Validate the whole supplied context first

- GIVEN nonblank bounded task and excerpt records use the existing advisory Unicode code-point limits
- WHEN any late excerpt is invalid, duplicated, missing its citation, or the count is outside 1–16
- THEN no inference is made and no partially ranked context is returned

#### Scenario: Separate task identity from excerpt identity

- GIVEN a task and an excerpt use the same ID spelling
- WHEN their texts differ
- THEN their independent namespaces remain valid
- AND only the task and excerpt texts enter the fixed question's state, not caller IDs or citations as authority

#### Scenario: Retain token-limited relevance evidence

- GIVEN an excerpt prediction reaches the reported input-token limit
- WHEN the call completes
- THEN the excerpt is retained with its complete response and token-limit flag
- AND the root count includes that prediction without converting the flag into a certainty or pruning decision

#### Scenario: Keep context ranking atomic

- GIVEN one or more excerpts were already scored
- WHEN a later score, distribution, legend, provenance, budget, deadline or cancellation is invalid
- THEN the whole call fails without retries or partial rankings
- AND exact caller cancellation wins, including while the final result settles

### Requirement: Test relevance without suite-skipping authority

r[onix.research-tools.laya-test-relevance] Native read-only `laya_test_relevance` MUST score 1–16 cited test descriptions against one supplied change. Each test MUST carry an explicit caller-provided required boolean. It MUST retain all tests, separate stable test_order from original result order, and return every required ID independently of relevance or token limits, without execution, measured coverage, minimized suites or permission to skip tests.

#### Scenario: Keep mandatory tests independent of ranking

- GIVEN caller-required tests include low-scoring or token-limited entries
- WHEN fractional relevance scores produce test_order
- THEN required_ids still includes every required test in original input order
- AND neither a zero score nor required false grants permission to skip a test

#### Scenario: Reject coerced required status before inference

- GIVEN earlier tests are valid
- WHEN a later required field is missing, null, numeric or a string rather than boolean
- THEN the entire input is rejected before any inference
- AND required status is never inferred from the model or truthiness coercion

#### Scenario: Preserve every candidate and tie

- GIVEN test descriptions have unique bounded IDs and citations
- WHEN equal or zero relevance scores occur
- THEN all tests and full predictions remain in input order
- AND test_order is a stable descending fractional ranking with no selected-only subset

#### Scenario: Bound the complete request without fetching tests

- GIVEN one bounded change record and 1–16 bounded cited tests use independent change/test ID namespaces
- WHEN any late citation, identity, text or array bound is invalid
- THEN no inference or source fetching occurs
- AND valid source references and required flags are preserved rather than presented as verified execution or coverage

#### Scenario: Share failure and cancellation across tests

- GIVEN earlier test scores succeeded
- WHEN a later prediction fails, provenance or budgets drift, or the single shared deadline/caller signal fires
- THEN no partial ranking, retry or run/skip decision is returned
- AND exact caller cancellation has precedence over a concurrent prediction failure

### Requirement: Issue routing with explicit uncertainty

r[onix.research-tools.laya-issue-route] Native read-only `laya_issue_route` MUST compare one supplied issue against 1–16 caller-described components or teams using fixed match, unclear and no_match choices. It MUST preserve every candidate and prediction and derive advisory single_match, ambiguous or no_match outcomes without assigning ownership, inventing absent catalog owners or treating confidence as a calibrated probability.

#### Scenario: Derive a single or absent match

- GIVEN every candidate is unflagged and none is unclear
- WHEN exactly one candidate is classified match
- THEN routing is single_match and matched_ids identifies it
- AND zero match labels instead produce no_match, without a confidence threshold or actual ownership assignment

#### Scenario: Preserve multiple and unclear possibilities

- GIVEN candidate predictions contain multiple matches or any unclear label
- WHEN the routing result is assembled
- THEN routing is ambiguous
- AND matched_ids and uncertain_ids preserve their respective original candidate order without dropping result rows

#### Scenario: Treat a clipped negative as uncertainty

- GIVEN a candidate's input-token limit is reached
- WHEN its label is no_match, match or unclear
- THEN its ID appears once in uncertain_ids and routing is ambiguous
- AND a flagged match remains in matched_ids as well, while a flagged no_match cannot make an otherwise sole match decisive

#### Scenario: Validate caller responsibility descriptions first

- GIVEN issue and candidate IDs occupy independent namespaces and all texts use existing advisory limits
- WHEN a candidate count, duplicate candidate ID or any late description is invalid
- THEN no inference occurs
- AND candidate descriptions alone are judged, with no catalog lookup or assignment action

#### Scenario: Keep routing all-or-error

- GIVEN earlier candidates have predictions
- WHEN a later response fails type/distribution/provenance/budget validation, exceeds the shared deadline or races cancellation
- THEN no partial routing is returned and no retries occur
- AND the caller's exact cancellation reason is preserved even with an uncooperative transport

### Requirement: Independent review-comment classification and priority

r[onix.research-tools.laya-review-triage] Native read-only `laya_review_triage` MUST retain 1–8 cited review comments about one supplied change and run classification followed by independent ordinal priority for each comment in one shared sequence. Kinds MUST be bug_report, design_concern, clarification_request, style_preference or other_or_unclear; kinds describe comments, not proof their authors are right. Separate stable review_order MUST preserve all IDs without automatic dismissal, resolution, edits or safety judgments.

#### Scenario: Keep the two heads independent and associated

- GIVEN comments have unique IDs and caller citations
- WHEN classification and fractional priority predictions are returned
- THEN each comment retains its own kind, priority and both complete predictions in input order
- AND priority is not derived from kind, while review_order uses descending numeric priority and original-order ties

#### Scenario: Retain low-priority and unclassified comments

- GIVEN a comment receives other_or_unclear or zero priority
- WHEN the tool completes
- THEN the original comment and both predictions remain present and its ID remains in review_order
- AND the tool neither dismisses the comment nor resolves the underlying discussion

#### Scenario: Validate bounds before either head

- GIVEN the change and citations use existing advisory bounds and independent change/comment ID namespaces
- WHEN a late comment is malformed, IDs repeat or the count is outside 1–8
- THEN no prediction is made
- AND eight valid comments produce exactly sixteen ordered predictions, not sixteen comments or separate per-comment deadlines

#### Scenario: Count token flags per prediction

- GIVEN classification and priority for the same comment both reach the input-token limit
- WHEN results are assembled
- THEN both flags and original responses are retained and the root token-limit count increases by two
- AND no clipped head is discarded or used as a defect or severity proof

#### Scenario: Reject cross-head and cross-comment failures

- GIVEN earlier heads or comments succeeded
- WHEN a later head has the wrong answer type, inconsistent score/legend, provenance/budget drift, transport failure or cancellation
- THEN no partial comments are returned and no retries occur
- AND one deadline covers all mixed heads with exact caller cancellation preserved

### Requirement: Pairwise requirement conflicts without rewriting

r[onix.research-tools.laya-requirement-conflict] Native read-only `laya_requirement_conflict` MUST assess 1–16 caller-supplied requirement pairs as compatible, conflicting or underspecified under their stated conditions. It MUST preserve pair and endpoint IDs, texts and full predictions, flag non-compatible or token-limited pairs for attention, and avoid rewriting, inferred precedence, exhaustive discovery or global consistency/satisfiability claims.

#### Scenario: Preserve uncertain compatibility for attention

- GIVEN pairs receive compatible, conflicting and underspecified labels
- WHEN attention_ids is produced
- THEN it includes every non-compatible or token-limit-flagged pair in input order
- AND a flagged compatible pair is not silently treated as established consistency

#### Scenario: Validate symmetric pair identities first

- GIVEN endpoint IDs share one namespace across both sides and all pairs
- WHEN repeated text conflicts, a self-pair occurs, pair IDs repeat or the same unordered pair appears again in either orientation
- THEN the complete input is rejected before any inference
- AND coherent reuse of a requirement across distinct pairs remains valid

#### Scenario: Keep delimiter-bearing identities distinct

- GIVEN endpoint IDs contain punctuation or object-property-like names
- WHEN different unordered pairs are checked
- THEN collision-safe nested identity tracking does not conflate them
- AND every original pair remains correctly associated with its own full prediction

#### Scenario: Judge only supplied conditions

- GIVEN a pair omits scope or conditions needed to compare the requirements
- WHEN the fixed English question runs
- THEN underspecified is available rather than inventing precedence or rewriting either requirement
- AND pairwise compatibility never becomes a global, transitive or exhaustive satisfiability verdict

#### Scenario: Preserve one bounded atomic execution

- GIVEN 1–16 bounded nonblank pairs passed full validation
- WHEN a later response, provenance, budget, shared deadline or cancellation fails
- THEN no partial judgments or retries are returned
- AND exact caller cancellation is preserved across all pairs
