import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { searchArxivQueries } from "./arxiv-multi-search";
import { rerankArxiv } from "./arxiv-rerank";
import {
  classifyLayaBatch,
  layaBatchOperation,
  type LayaBatchInput,
} from "./laya-batch";
import { layaPredictionResponseSchema, type LayaPredict } from "./laya-predict";
import {
  triageLayaFailures,
  layaFailureTriageOperation,
  type LayaFailureTriageInput,
} from "./laya-failure-triage";
import {
  triageLayaDiff,
  layaDiffTriageOperation,
  type LayaDiffTriageInput,
} from "./laya-diff-triage";
import {
  checkLayaDuplicates,
  layaDuplicateCheckOperation,
  type LayaDuplicateCheckInput,
} from "./laya-duplicate-check";
import {
  matchLayaEvidence,
  layaEvidenceMatchOperation,
  type LayaEvidenceMatchInput,
} from "./laya-evidence-match";
import {
  checkLayaCompletion,
  layaCompletionCheckOperation,
  type LayaCompletionCheckInput,
} from "./laya-completion-check";
import {
  rankLayaContext,
  layaContextRankOperation,
  type LayaContextRankInput,
} from "./laya-context-rank";
import {
  rankLayaTests,
  layaTestRelevanceOperation,
  type LayaTestRelevanceInput,
} from "./laya-test-relevance";
import {
  routeLayaIssue,
  layaIssueRouteOperation,
  type LayaIssueRouteInput,
} from "./laya-issue-route";
import {
  triageLayaReviews,
  layaReviewTriageOperation,
  type LayaReviewTriageInput,
} from "./laya-review-triage";
import {
  checkLayaRequirementConflicts,
  layaRequirementConflictOperation,
  type LayaRequirementConflictInput,
} from "./laya-requirement-conflict";
import endpoints from "./endpoints.json";
import {
  evaluateLaya,
  layaEvaluationOperation,
  type LayaEvaluationInput,
} from "./laya-evaluate";
import { registerLayaWatch } from "./laya-watch";
import operations from "./operations.json";

const MAX_RESPONSE_BYTES = 512 * 1024;

async function request(
  base: string,
  path: string,
  input: unknown,
  signal?: AbortSignal,
) {
  const timeout = AbortSignal.timeout(90_000);
  const response = await fetch(new URL(path, base), {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
    signal: signal ? AbortSignal.any([signal, timeout]) : timeout,
  });
  if (!response.body)
    throw new Error("Research service returned no response body");
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let bytes = 0;
  let text = "";
  try {
    for (;;) {
      const part = await reader.read();
      if (part.done) break;
      bytes += part.value.byteLength;
      if (bytes > MAX_RESPONSE_BYTES) {
        await reader.cancel();
        throw new Error(
          "Research response exceeds 512 KiB; request fewer results or a shorter page",
        );
      }
      text += decoder.decode(part.value, { stream: true });
    }
    text += decoder.decode();
  } finally {
    reader.releaseLock();
  }
  const data = JSON.parse(text);
  if (!response.ok)
    throw new Error(
      `Research service HTTP ${response.status}: ${data.error ?? text}`,
    );
  return {
    content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }],
    details: data,
  };
}

// r[impl onix.research-tools.omp]
export default function researchTools(pi: ExtensionAPI) {
  const arxivSearchResponse = pi.zod
    .object({
      dataset: pi.zod.string().regex(/\S/),
      revision: pi.zod.string().regex(/\S/),
      schema_version: pi.zod.number().int().positive(),
      results: pi.zod.array(
        pi.zod
          .object({
            paper_id: pi.zod.string().regex(/\S/),
            title: pi.zod.string().regex(/\S/),
            snippet: pi.zod.string(),
            rank: pi.zod.number().refine(Number.isFinite),
          })
          .passthrough(),
      ),
    })
    .passthrough();
  const predictionResponse = layaPredictionResponseSchema(pi.zod);
  const predict: LayaPredict = async (input, predictionSignal) =>
    predictionResponse.parse(
      (await request(endpoints.mesh, "/predict", input, predictionSignal))
        .details,
    );
  // r[impl onix.research-tools.laya-watch]
  registerLayaWatch(
    pi,
    async (input, signal) =>
      (await request(endpoints.mesh, "/predict", input, signal)).details,
  );
  // r[impl onix.research-tools.arxiv-rerank]
  // r[impl onix.research-tools.arxiv-multi-query]
  pi.registerTool({
    name: "arxiv_corpus",
    label: operations.arxiv_corpus.title,
    approval: "read",
    description:
      operations.arxiv_corpus.description +
      " OMP only: supply search-only queries instead of query for 2–4 complementary, nonblank, exact-distinct lexical FTS expressions of at most 500 Unicode characters each. The main model supplies these queries; none are generated automatically. limit is a shared total candidate budget (default 10, maximum 20, at least the query count); results are deduplicated by paper ID with per-query provenance. Supply search-only rerank_query (1–500 nonblank characters) with either retrieval mode to opt into Laya relevance reranking. Keep query or queries lexical; use rerank_query for natural-language relevance intent. Reranking preserves original ranks and provenance; inference failure returns the original retrieval order with a visible fallback reason. Scores are uncalibrated.",
    parameters: Type.Unsafe<{
      action: "search" | "read";
      query?: string;
      queries?: string[];
      rerank_query?: string;
      limit?: number;
      category?: string;
      paper_id?: string;
      offset?: number;
      length?: number;
    }>({
      ...operations.arxiv_corpus.inputSchema,
      properties: {
        ...operations.arxiv_corpus.inputSchema.properties,
        queries: {
          type: "array",
          minItems: 2,
          maxItems: 4,
          uniqueItems: true,
          items: {
            ...operations.arxiv_corpus.inputSchema.properties.query,
            pattern: "\\S",
          },
          description:
            "OMP-only, search-only complementary lexical queries supplied by the main model. Mutually exclusive with query; 2–4 nonblank, exact-distinct expressions, each at most 500 Unicode characters.",
        },
        limit: {
          ...operations.arxiv_corpus.inputSchema.properties.limit,
          description:
            "Maximum candidates for query, or shared total candidate budget for queries. Defaults to 10, maximum 20; with queries it must be at least the query count.",
        },
        rerank_query: {
          type: "string",
          minLength: 1,
          maxLength: 500,
          pattern: "\\S",
          description:
            "OMP-only, search-only natural-language relevance query. Presence opts into Laya reranking with query or queries; lexical retrieval expressions remain separate.",
        },
      },
    }),
    async execute(_id, args, signal) {
      if (args.rerank_query !== undefined) {
        if (args.action !== "search")
          throw new Error("rerank_query is only supported for search");
        if (typeof args.rerank_query !== "string" || !args.rerank_query.trim())
          throw new Error("rerank_query must be a nonblank string");
        let characters = 0;
        for (const _ of args.rerank_query) {
          if (++characters > 500)
            throw new Error("rerank_query must contain at most 500 characters");
        }
      }
      if (args.queries !== undefined) {
        if (args.action !== "search")
          throw new Error("queries is only supported for search");
        if (args.query !== undefined)
          throw new Error("query and queries are mutually exclusive");
        const search = await searchArxivQueries(
          args.queries,
          args.limit,
          args.category,
          async (input, searchSignal) =>
            arxivSearchResponse.parse(
              (await request(endpoints.mesh, "/search", input, searchSignal))
                .details,
            ),
          signal,
        );
        const details =
          args.rerank_query === undefined
            ? search
            : await rerankArxiv(
                search,
                args.rerank_query,
                async (input, scoringSignal) =>
                  (
                    await request(
                      endpoints.mesh,
                      "/predict",
                      input,
                      scoringSignal,
                    )
                  ).details,
                signal,
                "retrieval_position",
              );
        return {
          content: [
            { type: "text" as const, text: JSON.stringify(details, null, 2) },
          ],
          details,
        };
      }
      if (args.action === "search") {
        if (!args.query?.trim())
          throw new Error("query is required for search");
        const search = request(
          endpoints.mesh,
          "/search",
          { query: args.query, limit: args.limit, category: args.category },
          signal,
        );
        if (args.rerank_query === undefined) return search;
        const details = await rerankArxiv(
          (await search).details,
          args.rerank_query,
          async (input, scoringSignal) =>
            (await request(endpoints.mesh, "/predict", input, scoringSignal))
              .details,
          signal,
        );
        return {
          content: [
            { type: "text" as const, text: JSON.stringify(details, null, 2) },
          ],
          details,
        };
      }
      if (!args.paper_id) throw new Error("paper_id is required for read");
      return request(
        endpoints.mesh,
        "/paper",
        { paper_id: args.paper_id, offset: args.offset, length: args.length },
        signal,
      );
    },
  });
  pi.registerTool({
    name: "laya_decide",
    label: operations.laya_decide.title,
    approval: "read",
    strict: false,
    description: operations.laya_decide.description,
    parameters: Type.Unsafe<{
      state: string | Record<string, unknown>;
      questions: Record<
        string,
        {
          type: "choice" | "score" | "noul";
          instructions: string;
          criteria?: Record<string, string> | string[];
        }
      >;
    }>(operations.laya_decide.inputSchema),
    async execute(_id, args, signal) {
      return request(endpoints.mesh, "/predict", args, signal);
    },
  });
  // r[impl onix.research-tools.laya-evaluate]
  pi.registerTool({
    name: "laya_evaluate",
    label: layaEvaluationOperation.title,
    approval: "read",
    strict: false,
    description: layaEvaluationOperation.description,
    parameters: Type.Unsafe<LayaEvaluationInput>(
      layaEvaluationOperation.inputSchema,
    ),
    async execute(_id, args, signal) {
      const details = await evaluateLaya(args, predict, signal);
      return {
        content: [
          { type: "text" as const, text: JSON.stringify(details, null, 2) },
        ],
        details,
      };
    },
  });
  // r[impl onix.research-tools.laya-batch]
  pi.registerTool({
    name: "laya_batch",
    label: layaBatchOperation.title,
    approval: "read",
    strict: false,
    description: layaBatchOperation.description,
    parameters: Type.Unsafe<LayaBatchInput>(layaBatchOperation.inputSchema),
    async execute(_id, args, signal) {
      const details = await classifyLayaBatch(args, predict, signal);
      return {
        content: [
          { type: "text" as const, text: JSON.stringify(details, null, 2) },
        ],
        details,
      };
    },
  });
  // r[impl onix.research-tools.laya-failure-triage]
  pi.registerTool({
    name: "laya_failure_triage",
    label: layaFailureTriageOperation.title,
    approval: "read",
    strict: false,
    description: layaFailureTriageOperation.description,
    parameters: Type.Unsafe<LayaFailureTriageInput>(
      layaFailureTriageOperation.inputSchema,
    ),
    async execute(_id, args, signal) {
      const details = await triageLayaFailures(args, predict, signal);
      return {
        content: [
          { type: "text" as const, text: JSON.stringify(details, null, 2) },
        ],
        details,
      };
    },
  });
  // r[impl onix.research-tools.laya-diff-triage]
  pi.registerTool({
    name: "laya_diff_triage",
    label: layaDiffTriageOperation.title,
    approval: "read",
    strict: false,
    description: layaDiffTriageOperation.description,
    parameters: Type.Unsafe<LayaDiffTriageInput>(
      layaDiffTriageOperation.inputSchema,
    ),
    async execute(_id, args, signal) {
      const details = await triageLayaDiff(args, predict, signal);
      return {
        content: [
          { type: "text" as const, text: JSON.stringify(details, null, 2) },
        ],
        details,
      };
    },
  });
  // r[impl onix.research-tools.laya-duplicate-check]
  pi.registerTool({
    name: "laya_duplicate_check",
    label: layaDuplicateCheckOperation.title,
    approval: "read",
    strict: false,
    description: layaDuplicateCheckOperation.description,
    parameters: Type.Unsafe<LayaDuplicateCheckInput>(
      layaDuplicateCheckOperation.inputSchema,
    ),
    async execute(_id, args, signal) {
      const details = await checkLayaDuplicates(args, predict, signal);
      return {
        content: [
          { type: "text" as const, text: JSON.stringify(details, null, 2) },
        ],
        details,
      };
    },
  });
  // r[impl onix.research-tools.laya-evidence-match]
  pi.registerTool({
    name: "laya_evidence_match",
    label: layaEvidenceMatchOperation.title,
    approval: "read",
    strict: false,
    description: layaEvidenceMatchOperation.description,
    parameters: Type.Unsafe<LayaEvidenceMatchInput>(
      layaEvidenceMatchOperation.inputSchema,
    ),
    async execute(_id, args, signal) {
      const details = await matchLayaEvidence(args, predict, signal);
      return {
        content: [
          { type: "text" as const, text: JSON.stringify(details, null, 2) },
        ],
        details,
      };
    },
  });
  // r[impl onix.research-tools.laya-completion-check]
  pi.registerTool({
    name: "laya_completion_check",
    label: layaCompletionCheckOperation.title,
    approval: "read",
    strict: false,
    description: layaCompletionCheckOperation.description,
    parameters: Type.Unsafe<LayaCompletionCheckInput>(
      layaCompletionCheckOperation.inputSchema,
    ),
    async execute(_id, args, signal) {
      const details = await checkLayaCompletion(args, predict, signal);
      return {
        content: [
          { type: "text" as const, text: JSON.stringify(details, null, 2) },
        ],
        details,
      };
    },
  });
  // r[impl onix.research-tools.laya-context-rank]
  pi.registerTool({
    name: "laya_context_rank",
    label: layaContextRankOperation.title,
    approval: "read",
    strict: false,
    description: layaContextRankOperation.description,
    parameters: Type.Unsafe<LayaContextRankInput>(
      layaContextRankOperation.inputSchema,
    ),
    async execute(_id, args, signal) {
      const details = await rankLayaContext(args, predict, signal);
      return {
        content: [
          { type: "text" as const, text: JSON.stringify(details, null, 2) },
        ],
        details,
      };
    },
  });
  // r[impl onix.research-tools.laya-test-relevance]
  pi.registerTool({
    name: "laya_test_relevance",
    label: layaTestRelevanceOperation.title,
    approval: "read",
    strict: false,
    description: layaTestRelevanceOperation.description,
    parameters: Type.Unsafe<LayaTestRelevanceInput>(
      layaTestRelevanceOperation.inputSchema,
    ),
    async execute(_id, args, signal) {
      const details = await rankLayaTests(args, predict, signal);
      return {
        content: [
          { type: "text" as const, text: JSON.stringify(details, null, 2) },
        ],
        details,
      };
    },
  });
  // r[impl onix.research-tools.laya-issue-route]
  pi.registerTool({
    name: "laya_issue_route",
    label: layaIssueRouteOperation.title,
    approval: "read",
    strict: false,
    description: layaIssueRouteOperation.description,
    parameters: Type.Unsafe<LayaIssueRouteInput>(
      layaIssueRouteOperation.inputSchema,
    ),
    async execute(_id, args, signal) {
      const details = await routeLayaIssue(args, predict, signal);
      return {
        content: [
          { type: "text" as const, text: JSON.stringify(details, null, 2) },
        ],
        details,
      };
    },
  });
  // r[impl onix.research-tools.laya-review-triage]
  pi.registerTool({
    name: "laya_review_triage",
    label: layaReviewTriageOperation.title,
    approval: "read",
    strict: false,
    description: layaReviewTriageOperation.description,
    parameters: Type.Unsafe<LayaReviewTriageInput>(
      layaReviewTriageOperation.inputSchema,
    ),
    async execute(_id, args, signal) {
      const details = await triageLayaReviews(args, predict, signal);
      return {
        content: [
          { type: "text" as const, text: JSON.stringify(details, null, 2) },
        ],
        details,
      };
    },
  });
  // r[impl onix.research-tools.laya-requirement-conflict]
  pi.registerTool({
    name: "laya_requirement_conflict",
    label: layaRequirementConflictOperation.title,
    approval: "read",
    strict: false,
    description: layaRequirementConflictOperation.description,
    parameters: Type.Unsafe<LayaRequirementConflictInput>(
      layaRequirementConflictOperation.inputSchema,
    ),
    async execute(_id, args, signal) {
      const details = await checkLayaRequirementConflicts(
        args,
        predict,
        signal,
      );
      return {
        content: [
          { type: "text" as const, text: JSON.stringify(details, null, 2) },
        ],
        details,
      };
    },
  });
}
