import {
  layaIdSchema,
  predictLayaSequence,
  validateLayaItems,
  validateLayaQuestion,
  type LayaItem,
  type LayaPredict,
  type LayaPredictionResult,
  type LayaPredictionTask,
  type LayaQuestion,
} from "./laya-predict";
import operations from "./operations.json";

const LIMITATIONS = Object.freeze([
  "Caller-provided labels are not independently verified.",
  "The configured Laya base checkpoints are English-only, not the separately fine-tuned typed-decisions model.",
  "A tiny caller-labeled sample is not calibration, evidence of generalization, or authorization.",
  "Input-token-limit equality indicates possible truncation; a false flag cannot rule out earlier 192-token question/option truncation.",
] as const);
const COMPARISON_LIMITATIONS = Object.freeze([
  ...LIMITATIONS,
  "Matching labels cannot verify that both questions express the same task. Differences describe only these caller-labeled examples; no winner or statistical significance is inferred.",
]);

export interface LayaEvaluationInput {
  question: LayaQuestion;
  baseline_question?: LayaQuestion;
  examples: readonly (LayaItem & { expected: string | number | boolean })[];
}

export const layaEvaluationOperation = {
  title: "Laya caller-labeled evaluation",
  description:
    "Test one Laya choice, score, or noul question against 2–8 caller-labeled English examples using this client's existing inference route. Optionally supply baseline_question to compare question against a baseline on the same examples: types and choice labels must match, and score levels must be identical and ordered. Each example runs baseline then candidate, serially under one shared 15-second deadline for the entire operation. Comparison deltas are candidate minus baseline; lower Brier score or MAE is better, while higher accuracy is better. Per-example loss changes do not declare a winner. Labels are caller-provided, not independently verified; this is evaluation, not calibration or authorization. Reports accuracy/Brier score for choice/noul, or MAE on weighted ordinal scores. Boolean decisions use probability >= 0.5 (ties true). Any error or model drift fails the whole evaluation. Long inputs may be truncated, including the earlier 192-token question/option budget; token-limit flags cannot rule out that truncation. Tiny samples do not establish generalization. Probabilities are uncalibrated; confidence is not label probability.",
  inputSchema: {
    type: "object",
    properties: {
      question:
        operations.laya_decide.inputSchema.properties.questions
          .additionalProperties,
      baseline_question: {
        ...operations.laya_decide.inputSchema.properties.questions
          .additionalProperties,
        description:
          "Optional baseline for a paired comparison on the same examples. Must use the same type and choice-label set, or identical ordered score levels. The caller must ensure both questions express the same task.",
      },
      examples: {
        type: "array",
        minItems: 2,
        maxItems: 8,
        items: {
          type: "object",
          properties: {
            id: layaIdSchema,
            state: operations.laya_decide.inputSchema.properties.state,
            expected: {
              anyOf: [
                { type: "string" },
                { type: "number" },
                { type: "boolean" },
              ],
            },
          },
          required: ["id", "state", "expected"],
        },
      },
    },
    required: ["question", "examples"],
  },
};

export interface LayaEvaluationExampleResult extends LayaPredictionResult {
  expected: string | number | boolean;
}

type EvaluationSummary =
  | {
      accuracy: number;
      mean_brier_score: number;
      input_token_limit_reached: number;
    }
  | { mean_absolute_error: number; input_token_limit_reached: number };

interface EvaluationVariant {
  question: LayaEvaluationInput["question"];
  results: LayaEvaluationExampleResult[];
  correct: number;
  errorSum: number;
  tokenLimitReached: number;
}

interface PairedLoss {
  id: string;
  baseline_loss: number;
  candidate_loss: number;
  loss_delta: number;
}

export interface LayaEvaluationResult {
  status: "complete";
  question: LayaEvaluationInput["question"];
  label_source: "caller_provided";
  examples_evaluated: number;
  results: LayaEvaluationExampleResult[];
  elapsed_ms: number;
  summary: EvaluationSummary;
  comparison?: {
    baseline: {
      question: LayaEvaluationInput["question"];
      results: LayaEvaluationExampleResult[];
      summary: EvaluationSummary;
    };
    delta_direction: "candidate_minus_baseline";
    delta: EvaluationSummary;
    pairs: PairedLoss[];
    loss_changes: { improved: number; regressed: number; tied: number };
  };
  decision_threshold?: 0.5;
  limitations: readonly string[];
}

function validateInput(input: LayaEvaluationInput): string[] {
  if (input === null || typeof input !== "object" || Array.isArray(input))
    throw new Error("Invalid evaluation input");
  validateLayaItems(input.examples, 2, 8);
  const question = input.question;
  const labels = validateLayaQuestion(question);
  const baseline = input.baseline_question;
  if (baseline !== undefined) {
    const baselineLabels = validateLayaQuestion(baseline);
    if (
      baseline.type !== question.type ||
      baselineLabels.length !== labels.length ||
      labels.some((label) => !baselineLabels.includes(label))
    )
      throw new Error("Baseline must use the same question type and labels");
    if (question.type === "score") {
      const levels = question.criteria;
      const baselineLevels = baseline.criteria;
      if (
        !Array.isArray(levels) ||
        !Array.isArray(baselineLevels) ||
        levels.some((level, index) => level !== baselineLevels[index])
      )
        throw new Error("Baseline must use identical ordered score levels");
    }
  }

  for (const example of input.examples) {
    if (
      (question.type === "choice" &&
        (typeof example.expected !== "string" ||
          !labels.includes(example.expected))) ||
      (question.type === "score" &&
        (typeof example.expected !== "number" ||
          !Number.isInteger(example.expected) ||
          example.expected < 0 ||
          example.expected >= labels.length)) ||
      (question.type === "noul" && typeof example.expected !== "boolean")
    )
      throw new Error(
        `Invalid caller-provided label for example ${example.id}`,
      );
  }
  return labels;
}

function createVariant(
  question: LayaEvaluationInput["question"],
): EvaluationVariant {
  return {
    question,
    results: [],
    correct: 0,
    errorSum: 0,
    tokenLimitReached: 0,
  };
}

function summarize(variant: EvaluationVariant): EvaluationSummary {
  return variant.question.type === "score"
    ? {
        mean_absolute_error: variant.errorSum / variant.results.length,
        input_token_limit_reached: variant.tokenLimitReached,
      }
    : {
        accuracy: variant.correct / variant.results.length,
        mean_brier_score: variant.errorSum / variant.results.length,
        input_token_limit_reached: variant.tokenLimitReached,
      };
}

function recordPrediction(
  variant: EvaluationVariant,
  example: LayaEvaluationInput["examples"][number],
  prediction: LayaPredictionResult,
  labels: readonly string[],
  collectLoss: boolean,
): number {
  const answer = prediction.response.answers.evaluation;
  let loss = 0;
  switch (answer.type) {
    case "choice": {
      for (const label of labels) {
        const probability = answer.probabilities[label];
        const term = (probability - Number(label === example.expected)) ** 2;
        variant.errorSum += term;
        if (collectLoss) loss += term;
      }
      variant.correct += Number(prediction.actual === example.expected);
      break;
    }
    case "score": {
      loss = Math.abs(answer.score - Number(example.expected));
      variant.errorSum += loss;
      break;
    }
    case "noul": {
      variant.correct += Number(prediction.actual === example.expected);
      loss = (answer.noul - Number(example.expected)) ** 2;
      variant.errorSum += loss;
      break;
    }
  }
  variant.tokenLimitReached += Number(prediction.input_token_limit_reached);
  variant.results.push({
    id: prediction.id,
    expected: example.expected,
    actual: prediction.actual,
    response: prediction.response,
    input_token_limit_reached: prediction.input_token_limit_reached,
    elapsed_ms: prediction.elapsed_ms,
  });
  return loss;
}

// r[impl onix.research-tools.laya-evaluate]
// r[impl onix.research-tools.laya-paired-evaluation]
export async function evaluateLaya(
  input: LayaEvaluationInput,
  predict: LayaPredict,
  signal?: AbortSignal,
): Promise<LayaEvaluationResult> {
  signal?.throwIfAborted();
  const started = performance.now();
  const labels = validateInput(input);

  const candidate = createVariant(input.question);
  const baseline = input.baseline_question
    ? createVariant(input.baseline_question)
    : undefined;
  const variants = baseline ? [baseline, candidate] : [candidate];
  const pairs: PairedLoss[] | undefined = baseline ? [] : undefined;
  let improved = 0;
  let regressed = 0;
  let tied = 0;
  function* tasks(): Generator<LayaPredictionTask> {
    for (const example of input.examples) {
      for (const variant of variants) {
        yield {
          id: example.id,
          state: example.state,
          question: variant.question,
          labels,
        };
      }
    }
  }
  let exampleIndex = 0;
  let variantIndex = 0;
  let baselineLoss = 0;
  try {
    for await (const prediction of predictLayaSequence(
      tasks(),
      predict,
      signal,
    )) {
      const example = input.examples[exampleIndex];
      const variant = variants[variantIndex];
      const loss = recordPrediction(
        variant,
        example,
        prediction,
        labels,
        pairs !== undefined,
      );
      if (variant === baseline) {
        baselineLoss = loss;
      } else if (pairs) {
        const delta = loss - baselineLoss;
        pairs.push({
          id: example.id,
          baseline_loss: baselineLoss,
          candidate_loss: loss,
          loss_delta: delta,
        });
        if (delta < 0) improved++;
        else if (delta > 0) regressed++;
        else tied++;
      }
      if (++variantIndex === variants.length) {
        variantIndex = 0;
        exampleIndex++;
      }
    }
    signal?.throwIfAborted();
    const summary = summarize(candidate);
    let comparison: LayaEvaluationResult["comparison"];
    if (baseline && pairs) {
      const baselineSummary = summarize(baseline);
      const tokenDelta =
        candidate.tokenLimitReached - baseline.tokenLimitReached;
      let delta: EvaluationSummary;
      if (
        "mean_absolute_error" in summary &&
        "mean_absolute_error" in baselineSummary
      ) {
        delta = {
          mean_absolute_error:
            summary.mean_absolute_error - baselineSummary.mean_absolute_error,
          input_token_limit_reached: tokenDelta,
        };
      } else if (
        "mean_brier_score" in summary &&
        "mean_brier_score" in baselineSummary
      ) {
        delta = {
          accuracy: summary.accuracy - baselineSummary.accuracy,
          mean_brier_score:
            summary.mean_brier_score - baselineSummary.mean_brier_score,
          input_token_limit_reached: tokenDelta,
        };
      } else {
        throw new Error("Baseline and candidate metric types do not match");
      }
      comparison = {
        baseline: {
          question: baseline.question,
          results: baseline.results,
          summary: baselineSummary,
        },
        delta_direction: "candidate_minus_baseline",
        delta,
        pairs,
        loss_changes: { improved, regressed, tied },
      };
    }
    return {
      status: "complete",
      question: input.question,
      label_source: "caller_provided",
      examples_evaluated: candidate.results.length,
      results: candidate.results,
      elapsed_ms: performance.now() - started,
      summary,
      ...(comparison ? { comparison } : {}),
      ...(input.question.type === "noul"
        ? { decision_threshold: 0.5 as const }
        : {}),
      limitations: baseline ? COMPARISON_LIMITATIONS : LIMITATIONS,
    };
  } catch (error) {
    // Preserve the caller's exact reason, even when cancellation races a failure.
    signal?.throwIfAborted();
    throw error;
  }
}
