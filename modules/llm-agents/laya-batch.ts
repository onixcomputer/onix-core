import operations from "./operations.json";
import {
  type LayaItem,
  type LayaPredict,
  type LayaPredictionResult,
  type LayaPredictionTask,
  type LayaQuestion,
  layaIdSchema,
  predictLayaSequence,
  validateLayaItems,
  validateLayaQuestion,
} from "./laya-predict";

const LIMITATIONS = Object.freeze([
  "The configured Laya base checkpoints are English-only, not the separately fine-tuned typed-decisions model.",
  "Probabilities are uncalibrated, and reported confidence is not a label probability.",
  "Unlabeled predictions do not establish accuracy, calibration, generalization, safety, or authorization; no automatic action is taken.",
  "Input-token-limit equality indicates possible truncation; a false flag cannot rule out earlier 192-token question/option truncation. Full responses retain original provenance.",
] as const);

export interface LayaBatchInput {
  question: LayaQuestion;
  items: readonly LayaItem[];
}

export const layaBatchOperation = {
  title: "Laya unlabeled batch classification",
  description:
    "Classify 1–16 unlabeled English items with one Laya choice, score, or noul question using this client's existing inference route. All inputs are validated before inference; predictions run serially under one shared 15-second deadline with all-or-error results and no retries. Retains input order, complete predictions and provenance, per-item timing and token-limit flags, and a token-limit count. Noul uses a fixed 0.5 threshold with ties true. No gold labels, accuracy or loss metrics, sorting, text clipping, or autonomous authorization; predictions are uncalibrated and do not authorize actions.",
  inputSchema: {
    type: "object",
    properties: {
      question:
        operations.laya_decide.inputSchema.properties.questions
          .additionalProperties,
      items: {
        type: "array",
        minItems: 1,
        maxItems: 16,
        items: {
          type: "object",
          properties: {
            id: layaIdSchema,
            state: operations.laya_decide.inputSchema.properties.state,
          },
          required: ["id", "state"],
        },
      },
    },
    required: ["question", "items"],
  },
};

// r[impl onix.research-tools.laya-batch]
export async function classifyLayaBatch(
  input: LayaBatchInput,
  predict: LayaPredict,
  signal?: AbortSignal,
) {
  signal?.throwIfAborted();
  const started = performance.now();
  if (input === null || typeof input !== "object" || Array.isArray(input))
    throw new Error("Invalid batch input");
  const labels = validateLayaQuestion(input.question);
  validateLayaItems(input.items, 1, 16);

  function* tasks(): Iterable<LayaPredictionTask> {
    for (const item of input.items)
      yield {
        id: item.id,
        state: item.state,
        question: input.question,
        labels,
      };
  }

  const results: LayaPredictionResult[] = [];
  let inputTokenLimitReached = 0;
  for await (const result of predictLayaSequence(tasks(), predict, signal)) {
    results.push(result);
    if (result.input_token_limit_reached) inputTokenLimitReached++;
  }
  signal?.throwIfAborted();
  return {
    status: "complete" as const,
    question: input.question,
    items_processed: results.length,
    results,
    elapsed_ms: performance.now() - started,
    input_token_limit_reached: inputTokenLimitReached,
    ...(input.question.type === "noul" ? { decision_threshold: 0.5 } : {}),
    limitations: LIMITATIONS,
  };
}
