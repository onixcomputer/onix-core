import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const PREDICTION_MS = 15_000;
const PROBABILITY_TOLERANCE = 1e-4;
const IDENTITY_FIELDS = [
  "model",
  "revision",
  "device",
  "sdk_version",
  "runtime",
  "dtype",
  "artifact_model",
  "artifact_revision",
  "max_tokens_per_question",
  "head_max_tokens",
] as const;

export const layaIdSchema = {
  type: "string",
  minLength: 1,
  maxLength: 64,
  pattern: "\\S",
};

export interface LayaQuestion {
  type: "choice" | "score" | "noul";
  instructions: string;
  criteria?: Record<string, string> | string[];
}

export interface LayaItem {
  id: string;
  state: string | Record<string, unknown>;
}

export type LayaAnswer = (
  | {
      type: "choice";
      choice: string;
      probabilities: Record<string, number>;
    }
  | {
      type: "score";
      score: number;
      probabilities: Record<string, number>;
      legend: Record<string, string>;
    }
  | { type: "noul"; noul: number }
) &
  Record<string, unknown>;

export interface LayaPrediction {
  model: string;
  revision: string;
  device: string;
  sdk_version: string;
  runtime?: string;
  dtype?: string;
  artifact_model?: string;
  artifact_revision?: string;
  max_tokens_per_question: number;
  head_max_tokens: number;
  usage: {
    input_tokens: number;
    output_tokens: number;
    [key: string]: unknown;
  };
  answers: { evaluation: LayaAnswer };
  [key: string]: unknown;
}

export type LayaPredict = (
  request: {
    state: LayaItem["state"];
    questions: { evaluation: LayaQuestion };
  },
  signal: AbortSignal,
) => Promise<LayaPrediction>;

export interface LayaPredictionTask extends LayaItem {
  question: LayaQuestion;
  labels: readonly string[];
}

export interface LayaPredictionResult {
  id: string;
  actual: string | number | boolean;
  response: LayaPrediction;
  input_token_limit_reached: boolean;
  elapsed_ms: number;
}

export function layaPredictionResponseSchema(z: ExtensionAPI["zod"]) {
  const nonblank = z.string().regex(/\S/u);
  const probability = z.number().min(0).max(1).refine(Number.isFinite);
  const probabilities = z.record(z.string(), probability);
  const positiveInteger = z.number().int().positive();
  return z
    .object({
      model: nonblank,
      revision: nonblank,
      device: nonblank,
      sdk_version: nonblank,
      runtime: nonblank.optional(),
      dtype: nonblank.optional(),
      artifact_model: nonblank.optional(),
      artifact_revision: nonblank.optional(),
      max_tokens_per_question: positiveInteger,
      head_max_tokens: positiveInteger,
      usage: z
        .object({
          input_tokens: positiveInteger,
          output_tokens: z.number().int().nonnegative(),
        })
        .passthrough(),
      answers: z
        .object({
          evaluation: z.union([
            z
              .object({
                type: z.literal("choice"),
                choice: z.string(),
                probabilities,
              })
              .passthrough(),
            z
              .object({
                type: z.literal("score"),
                score: z.number().refine(Number.isFinite),
                probabilities,
                legend: z.record(z.string(), z.string()),
              })
              .passthrough(),
            z
              .object({ type: z.literal("noul"), noul: probability })
              .passthrough(),
          ]),
        })
        .strict(),
    })
    .passthrough()
    .refine(
      (response) => response.head_max_tokens < response.max_tokens_per_question,
      {
        message: "Question/option token budget must be below the total budget",
      },
    )
    .refine(
      (response) =>
        response.usage.input_tokens <= response.max_tokens_per_question,
      { message: "Input usage exceeds the single-question token budget" },
    );
}

export function boundedText(value: unknown, maximum: number): value is string {
  if (typeof value !== "string" || !/\S/u.test(value)) return false;
  let length = 0;
  for (const _character of value) if (++length > maximum) return false;
  return true;
}

export function validateLayaQuestion(question: LayaQuestion): string[] {
  if (
    question === null ||
    typeof question !== "object" ||
    Array.isArray(question) ||
    (question.type !== "choice" &&
      question.type !== "score" &&
      question.type !== "noul") ||
    !boundedText(question.instructions, 1000)
  )
    throw new Error("Invalid evaluation question or instructions");

  const criteria = question.criteria;
  let labels: string[];
  if (question.type === "noul" && criteria === undefined) {
    labels = ["false", "true"];
  } else {
    if (
      criteria === null ||
      typeof criteria !== "object" ||
      (question.type === "score" && !Array.isArray(criteria)) ||
      (question.type === "noul" && Array.isArray(criteria))
    )
      throw new Error("Invalid criteria for the requested question type");
    const names = Array.isArray(criteria) ? criteria : Object.keys(criteria);
    if (
      names.length < 2 ||
      names.length > 20 ||
      names.some((name) => !boundedText(name, 500)) ||
      new Set(names).size !== names.length ||
      (!Array.isArray(criteria) &&
        Object.values(criteria).some((value) => !boundedText(value, 500))) ||
      (question.type === "noul" &&
        (names.length !== 2 ||
          !names.includes("false") ||
          !names.includes("true")))
    )
      throw new Error("Invalid criterion labels or descriptions");
    labels =
      question.type === "score"
        ? names.map((_name, index) => String(index))
        : names;
  }
  return labels;
}

export function validateLayaIds(
  items: readonly { id: string }[],
  minimum: number,
  maximum: number,
): void {
  if (!Array.isArray(items) || items.length < minimum || items.length > maximum)
    throw new Error(`Prediction requires ${minimum}–${maximum} items`);
  const ids = new Set<string>();
  for (const item of items) {
    if (
      item === null ||
      typeof item !== "object" ||
      Array.isArray(item) ||
      !boundedText(item.id, 64) ||
      ids.has(item.id)
    )
      throw new Error("Item IDs must be unique, nonblank, and 1–64 characters");
    ids.add(item.id);
  }
}

export function validateLayaItems(
  items: readonly LayaItem[],
  minimum: number,
  maximum: number,
): void {
  validateLayaIds(items, minimum, maximum);
  for (const item of items) {
    if (
      typeof item.state !== "string" &&
      (item.state === null ||
        typeof item.state !== "object" ||
        Array.isArray(item.state))
    )
      throw new Error(`Invalid state for item ${item.id}`);
  }
}

function validateDistribution(
  probabilities: Record<string, number>,
  labels: readonly string[],
): void {
  if (
    Object.keys(probabilities).length !== labels.length ||
    labels.some((label) => !Object.hasOwn(probabilities, label))
  )
    throw new Error("Prediction probability labels do not match the question");
  let mass = 0;
  for (const label of labels) {
    const probability = probabilities[label];
    if (!Number.isFinite(probability) || probability < 0 || probability > 1)
      throw new Error("Invalid label probability");
    mass += probability;
  }
  if (Math.abs(mass - 1) > PROBABILITY_TOLERANCE * labels.length)
    throw new Error("Prediction probability mass does not sum to one");
}

function validateAnswer(
  task: LayaPredictionTask,
  answer: LayaAnswer,
): string | number | boolean {
  if (answer.type !== task.question.type)
    throw new Error("Prediction answer type does not match the question");
  const labels = task.labels;
  switch (answer.type) {
    case "choice": {
      validateDistribution(answer.probabilities, labels);
      if (!labels.includes(answer.choice))
        throw new Error("Predicted choice is not a declared label");
      for (const label of labels) {
        if (answer.probabilities[label] > answer.probabilities[answer.choice])
          throw new Error(
            "Predicted choice does not maximize label probability",
          );
      }
      return answer.choice;
    }
    case "score": {
      validateDistribution(answer.probabilities, labels);
      const levels = task.question.criteria;
      if (
        !Array.isArray(levels) ||
        Object.keys(answer.legend).length !== labels.length ||
        labels.some(
          (label, index) =>
            !Object.hasOwn(answer.legend, label) ||
            answer.legend[label] !== levels[index],
        )
      )
        throw new Error("Prediction score legend does not match the question");
      let weightedMean = 0;
      for (let index = 0; index < labels.length; index++)
        weightedMean += index * answer.probabilities[labels[index]];
      const tolerance =
        PROBABILITY_TOLERANCE * (1 + (labels.length * (labels.length - 1)) / 2);
      if (
        !Number.isFinite(answer.score) ||
        answer.score < 0 ||
        answer.score > labels.length - 1 ||
        Math.abs(answer.score - weightedMean) > tolerance
      )
        throw new Error(
          "Prediction score disagrees with its ordinal probabilities",
        );
      return answer.score;
    }
    case "noul": {
      if (!Number.isFinite(answer.noul) || answer.noul < 0 || answer.noul > 1)
        throw new Error("Invalid boolean label probability");
      return answer.noul >= 0.5;
    }
  }
}

// r[impl onix.research-tools.laya-evaluate]
// r[impl onix.research-tools.laya-paired-evaluation]
// r[impl onix.research-tools.laya-batch]
export async function* predictLayaSequence(
  tasks: Iterable<LayaPredictionTask>,
  predict: LayaPredict,
  signal?: AbortSignal,
): AsyncGenerator<LayaPredictionResult> {
  signal?.throwIfAborted();
  const controller = new AbortController();
  const deadline = performance.now() + PREDICTION_MS;
  const timeoutError = new Error("15-second evaluation deadline exceeded");
  const timer = setTimeout(() => controller.abort(timeoutError), PREDICTION_MS);
  const cancel = () => controller.abort(signal?.reason);
  signal?.addEventListener("abort", cancel, { once: true });
  let rejectAbort: ((reason: unknown) => void) | undefined;
  let aborted: Promise<never> | undefined;
  const onAbort = () => rejectAbort?.(controller.signal.reason);
  controller.signal.addEventListener("abort", onAbort, { once: true });
  let identity:
    | Partial<Record<(typeof IDENTITY_FIELDS)[number], string | number>>
    | undefined;
  try {
    for (const task of tasks) {
      signal?.throwIfAborted();
      if (performance.now() >= deadline) throw timeoutError;
      const started = performance.now();
      // Race cancellation even when the transport ignores abort. Deferring the
      // call also attaches rejection handlers before synchronous errors/aborts.
      const response = await Promise.race([
        (aborted ??= new Promise<never>((_resolve, reject) => {
          rejectAbort = reject;
        })),
        Promise.resolve().then(() => {
          controller.signal.throwIfAborted();
          return predict(
            {
              state: task.state,
              questions: { evaluation: task.question },
            },
            controller.signal,
          );
        }),
      ]);
      signal?.throwIfAborted();
      if (performance.now() >= deadline) throw timeoutError;
      controller.signal.throwIfAborted();
      for (const key of IDENTITY_FIELDS) {
        if (
          identity &&
          (identity[key] !== response[key] ||
            Object.hasOwn(identity, key) !== Object.hasOwn(response, key))
        )
          throw new Error(
            "Model, runtime, or token budgets changed between predictions",
          );
      }
      if (!identity) {
        identity = {};
        for (const key of IDENTITY_FIELDS)
          if (Object.hasOwn(response, key)) identity[key] = response[key];
      }
      const actual = validateAnswer(task, response.answers.evaluation);
      yield {
        id: task.id,
        actual,
        response,
        input_token_limit_reached:
          response.usage.input_tokens === response.max_tokens_per_question,
        elapsed_ms: performance.now() - started,
      };
    }
    signal?.throwIfAborted();
    if (performance.now() >= deadline) throw timeoutError;
    controller.signal.throwIfAborted();
  } catch (error) {
    // Preserve the caller's exact reason, even when cancellation races a failure.
    signal?.throwIfAborted();
    throw error;
  } finally {
    clearTimeout(timer);
    signal?.removeEventListener("abort", cancel);
    controller.signal.removeEventListener("abort", onAbort);
  }
}
