const CRITERIA = Object.freeze([
  "unrelated",
  "same broad topic but not useful",
  "partly useful",
  "directly useful",
] as const);
const INSTRUCTIONS =
  "How useful is the passage for answering the search query?";
const TITLE_CHARS = 240;
const SNIPPET_CHARS = 600;
const SCORING_MS = 15_000;
const MODEL_FIELDS = [
  "model",
  "revision",
  "runtime",
  "device",
  "sdk_version",
  "dtype",
  "artifact_model",
  "artifact_revision",
] as const;

export interface ArxivSearchResult {
  paper_id: string;
  title: string;
  snippet: string;
  rank: number;
  [key: string]: unknown;
}

export interface ArxivSearchResponse {
  results: readonly ArxivSearchResult[];
  [key: string]: unknown;
}

export interface ArxivPredictRequest {
  state: { query: string; passage: string };
  questions: {
    relevance: {
      type: "score";
      instructions: typeof INSTRUCTIONS;
      criteria: typeof CRITERIA;
    };
  };
}

export type ArxivPredict = (
  request: ArxivPredictRequest,
  signal: AbortSignal,
) => Promise<unknown>;

export interface ArxivRerankModel {
  model: string;
  revision: string;
  device: string;
  sdk_version: string;
  runtime?: string;
  dtype?: string;
  artifact_model?: string;
  artifact_revision?: string;
}

export type ArxivRerankedResult = ArxivSearchResult & {
  laya_score: number;
  laya_input_truncated: boolean;
} & ({ bm25_position: number } | { retrieval_position: number });

export type ArxivRerankMetadata =
  | {
      status: "applied";
      query: string;
      score_range: readonly [0, 3];
      criteria: typeof CRITERIA;
      model: ArxivRerankModel;
      input_limits: { title_chars: 240; snippet_chars: 600 };
    }
  | { status: "fallback"; query: string; reason: string }
  | { status: "skipped"; query: string; reason: "no_results" };

export interface ArxivRerankResponse extends ArxivSearchResponse {
  results: readonly (ArxivSearchResult | ArxivRerankedResult)[];
  rerank: ArxivRerankMetadata;
}

function nonblank(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

function judgment(value: unknown): { score: number; model: ArxivRerankModel } {
  const response =
    value !== null && typeof value === "object" && !Array.isArray(value)
      ? value
      : undefined;
  const answers =
    response && "answers" in response ? response.answers : undefined;
  const answer =
    answers !== null &&
    typeof answers === "object" &&
    !Array.isArray(answers) &&
    "relevance" in answers
      ? answers.relevance
      : undefined;
  if (
    answer === null ||
    typeof answer !== "object" ||
    Array.isArray(answer) ||
    !("type" in answer) ||
    answer.type !== "score" ||
    !("score" in answer) ||
    typeof answer.score !== "number" ||
    !Number.isFinite(answer.score) ||
    answer.score < 0 ||
    answer.score > 3
  )
    throw new Error(
      "invalid relevance score; expected a finite number in [0, 3]",
    );

  const usage = response && "usage" in response ? response.usage : undefined;
  const tokens =
    usage !== null &&
    typeof usage === "object" &&
    !Array.isArray(usage) &&
    "input_tokens" in usage
      ? usage.input_tokens
      : undefined;
  if (
    typeof tokens !== "number" ||
    !Number.isSafeInteger(tokens) ||
    tokens <= 0
  )
    throw new Error("missing or invalid input token usage");
  if (tokens >= 512)
    throw new Error(
      "input token budget reached; backend truncation is possible",
    );

  if (
    !response ||
    !("model" in response) ||
    !nonblank(response.model) ||
    !("revision" in response) ||
    !nonblank(response.revision) ||
    !("device" in response) ||
    !nonblank(response.device) ||
    !("sdk_version" in response) ||
    !nonblank(response.sdk_version)
  )
    throw new Error("missing model, revision, device, or SDK provenance");
  const runtime = "runtime" in response ? response.runtime : undefined;
  const dtype = "dtype" in response ? response.dtype : undefined;
  const artifact_model =
    "artifact_model" in response ? response.artifact_model : undefined;
  const artifact_revision =
    "artifact_revision" in response ? response.artifact_revision : undefined;
  if (
    (runtime !== undefined && !nonblank(runtime)) ||
    (dtype !== undefined && !nonblank(dtype)) ||
    (artifact_model !== undefined && !nonblank(artifact_model)) ||
    (artifact_revision !== undefined && !nonblank(artifact_revision))
  )
    throw new Error("invalid runtime, dtype, or artifact provenance");

  return {
    score: answer.score,
    model: {
      model: response.model,
      revision: response.revision,
      device: response.device,
      sdk_version: response.sdk_version,
      ...(runtime !== undefined ? { runtime } : {}),
      ...(dtype !== undefined ? { dtype } : {}),
      ...(artifact_model !== undefined ? { artifact_model } : {}),
      ...(artifact_revision !== undefined ? { artifact_revision } : {}),
    },
  };
}

function fallback(
  search: ArxivSearchResponse,
  query: string,
  reason: string,
): ArxivRerankResponse {
  return { ...search, rerank: { status: "fallback", query, reason } };
}

export async function rerankArxiv(
  search: ArxivSearchResponse,
  relevanceQuery: string,
  predict: ArxivPredict,
  signal?: AbortSignal,
  positionField: "bm25_position" | "retrieval_position" = "bm25_position",
): Promise<ArxivRerankResponse> {
  signal?.throwIfAborted();
  if (!Array.isArray(search.results) || search.results.length > 20)
    return fallback(
      search,
      relevanceQuery,
      "expected an array of at most 20 candidates",
    );
  if (search.results.length === 0)
    return {
      ...search,
      rerank: {
        status: "skipped",
        query: relevanceQuery,
        reason: "no_results",
      },
    };
  for (let index = 0; index < search.results.length; index++) {
    const candidate = search.results[index];
    if (
      candidate === null ||
      typeof candidate !== "object" ||
      Array.isArray(candidate) ||
      !nonblank(candidate.paper_id) ||
      !nonblank(candidate.title) ||
      typeof candidate.snippet !== "string" ||
      typeof candidate.rank !== "number" ||
      !Number.isFinite(candidate.rank)
    )
      return fallback(
        search,
        relevanceQuery,
        `invalid candidate at ${positionField === "bm25_position" ? "BM25" : "retrieval"} position ${index + 1}`,
      );
  }

  const controller = new AbortController();
  const deadline = performance.now() + SCORING_MS;
  const timeoutError = new Error("15-second scoring deadline exceeded");
  const timer = setTimeout(() => controller.abort(timeoutError), SCORING_MS);
  const cancel = () => controller.abort(signal?.reason);
  signal?.addEventListener("abort", cancel, { once: true });
  let rejectAbort!: (reason: unknown) => void;
  const aborted = new Promise<never>((_resolve, reject) => {
    rejectAbort = reject;
  });
  const onAbort = () => rejectAbort(controller.signal.reason);
  controller.signal.addEventListener("abort", onAbort, { once: true });
  const scored: ArxivRerankedResult[] = [];
  let model: ArxivRerankModel | undefined;
  let position = 0;
  try {
    for (const candidate of search.results) {
      position++;
      signal?.throwIfAborted();
      if (performance.now() >= deadline) throw timeoutError;
      const request: ArxivPredictRequest = {
        state: {
          query: relevanceQuery,
          passage: `${candidate.title.slice(0, TITLE_CHARS)}\n${candidate.snippet.slice(0, SNIPPET_CHARS)}`,
        },
        questions: {
          relevance: {
            type: "score",
            instructions: INSTRUCTIONS,
            criteria: CRITERIA,
          },
        },
      };
      // Race cancellation even if the transport ignores abort. Defer invocation so
      // synchronous transport errors/aborts also have rejection handlers attached.
      const raw = await Promise.race([
        aborted,
        Promise.resolve().then(() => {
          controller.signal.throwIfAborted();
          return predict(request, controller.signal);
        }),
      ]);
      signal?.throwIfAborted();
      if (performance.now() >= deadline) throw timeoutError;
      controller.signal.throwIfAborted();
      const answer = judgment(raw);
      for (const key of MODEL_FIELDS) {
        if (model && model[key] !== answer.model[key])
          throw new Error(
            "model or runtime provenance changed between candidates",
          );
      }
      model = answer.model;
      const inputTruncated =
        candidate.title.length > TITLE_CHARS ||
        candidate.snippet.length > SNIPPET_CHARS;
      scored.push(
        positionField === "bm25_position"
          ? {
              ...candidate,
              laya_score: answer.score,
              bm25_position: position,
              laya_input_truncated: inputTruncated,
            }
          : {
              ...candidate,
              laya_score: answer.score,
              retrieval_position: position,
              laya_input_truncated: inputTruncated,
            },
      );
    }
    signal?.throwIfAborted();
    // Stable sorting preserves the input retrieval order on exact score ties.
    scored.sort((left, right) => right.laya_score - left.laya_score);
    return {
      ...search,
      results: scored,
      rerank: {
        status: "applied",
        query: relevanceQuery,
        score_range: [0, 3],
        criteria: CRITERIA,
        // Nonempty candidates and successful judgments establish this provenance.
        model: model!,
        input_limits: {
          title_chars: TITLE_CHARS,
          snippet_chars: SNIPPET_CHARS,
        },
      },
    };
  } catch (error) {
    // A caller abort is not a successful baseline answer, even when it races an error.
    signal?.throwIfAborted();
    const reason =
      error instanceof Error
        ? error.message
        : typeof error === "string"
          ? error
          : "inference failed";
    return fallback(
      search,
      relevanceQuery,
      `candidate ${position}: ${reason.slice(0, 240)}`,
    );
  } finally {
    clearTimeout(timer);
    signal?.removeEventListener("abort", cancel);
    controller.signal.removeEventListener("abort", onAbort);
  }
}
