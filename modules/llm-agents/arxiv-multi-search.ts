import type { ArxivSearchResponse, ArxivSearchResult } from "./arxiv-rerank";

export type ArxivQuerySearch = (
  request: { query: string; limit: number; category?: string },
  signal: AbortSignal,
) => Promise<ArxivSearchResponse>;

export interface ArxivRetrievalSource {
  query_index: number;
  bm25_position: number;
  rank: number;
  snippet: string;
}

export interface ArxivMultiSearchResult extends ArxivSearchResult {
  retrieval_position: number;
  retrieval_sources: ArxivRetrievalSource[];
}

export interface ArxivMultiSearchResponse extends ArxivSearchResponse {
  results: ArxivMultiSearchResult[];
  retrieval: {
    mode: "multi_query";
    merge_order: "round_robin";
    budget: number;
    fetched_count: number;
    unique_count: number;
    queries: {
      query: string;
      limit: number;
      returned: number;
      metadata: Omit<ArxivSearchResponse, "results">;
    }[];
  };
}

// r[impl onix.research-tools.arxiv-multi-query]
export async function searchArxivQueries(
  queries: readonly string[],
  limit: number | undefined,
  category: string | undefined,
  search: ArxivQuerySearch,
  signal?: AbortSignal,
): Promise<ArxivMultiSearchResponse> {
  signal?.throwIfAborted();
  if (!Array.isArray(queries) || queries.length < 2 || queries.length > 4)
    throw new Error("multi-query retrieval requires 2–4 queries");
  const distinct = new Set<string>();
  for (const query of queries) {
    if (typeof query !== "string" || query.trim().length === 0)
      throw new Error("each retrieval query must be a nonblank string");
    let codePoints = 0;
    for (const _character of query) {
      if (++codePoints > 500)
        throw new Error("each retrieval query must be at most 500 code points");
    }
    if (distinct.has(query))
      throw new Error("retrieval queries must be exact-distinct strings");
    distinct.add(query);
  }
  const budget = limit === undefined ? 10 : limit;
  if (!Number.isInteger(budget) || budget < queries.length || budget > 20)
    throw new Error(
      "retrieval limit must be an integer from query count to 20",
    );

  const minimum = Math.floor(budget / queries.length);
  const remainder = budget % queries.length;
  const requests = queries.map((query, index) => ({
    query,
    limit: minimum + (index < remainder ? 1 : 0),
    category,
  }));
  const controller = new AbortController();
  let rejectAbort!: (reason: unknown) => void;
  const aborted = new Promise<never>((_resolve, reject) => {
    rejectAbort = reject;
  });
  const onAbort = () => rejectAbort(controller.signal.reason);
  const cancel = () => controller.abort(signal?.reason);
  controller.signal.addEventListener("abort", onAbort, { once: true });
  signal?.addEventListener("abort", cancel, { once: true });
  let snapshot: ArxivSearchResponse | undefined;
  try {
    const responses = await Promise.race([
      aborted,
      Promise.all(
        requests.map((request) =>
          // Defer invocation until the whole wave has rejection handlers, even
          // when a transport throws synchronously or cancels the caller.
          Promise.resolve().then(async () => {
            signal?.throwIfAborted();
            controller.signal.throwIfAborted();
            const response = await search(request, controller.signal);
            controller.signal.throwIfAborted();
            if (response.results.length > request.limit)
              throw new Error(
                "corpus response exceeds its assigned query quota",
              );
            if (
              snapshot &&
              (response.dataset !== snapshot.dataset ||
                response.revision !== snapshot.revision ||
                response.schema_version !== snapshot.schema_version)
            )
              throw new Error(
                "corpus snapshot changed between retrieval queries",
              );
            snapshot ??= response;
            return response;
          }),
        ),
      ),
    ]);
    signal?.throwIfAborted();
    const results: ArxivMultiSearchResult[] = [];
    const papers = new Map<string, ArxivMultiSearchResult>();
    let fetchedCount = 0;
    // Position, not score, is comparable across independently ranked queries.
    for (let position = 0; position < requests[0].limit; position++) {
      for (let queryIndex = 0; queryIndex < responses.length; queryIndex++) {
        const candidate = responses[queryIndex].results[position];
        if (!candidate) continue;
        fetchedCount++;
        const source: ArxivRetrievalSource = {
          query_index: queryIndex,
          bm25_position: position + 1,
          rank: candidate.rank,
          snippet: candidate.snippet,
        };
        const existing = papers.get(candidate.paper_id);
        if (existing) {
          existing.retrieval_sources.push(source);
        } else {
          const paper: ArxivMultiSearchResult = {
            ...candidate,
            retrieval_position: results.length + 1,
            retrieval_sources: [source],
          };
          papers.set(candidate.paper_id, paper);
          results.push(paper);
        }
      }
    }
    const {
      results: _results,
      query: _query,
      limit: _limit,
      category: _category,
      ...metadata
    } = responses[0];
    return {
      ...metadata,
      results,
      retrieval: {
        mode: "multi_query",
        merge_order: "round_robin",
        budget,
        fetched_count: fetchedCount,
        unique_count: results.length,
        queries: responses.map(
          ({ results: candidates, ...metadata }, index) => ({
            query: requests[index].query,
            limit: requests[index].limit,
            returned: candidates.length,
            metadata,
          }),
        ),
      },
    };
  } catch (error) {
    controller.abort(error);
    // A caller cancellation wins even when a transport failure races it.
    signal?.throwIfAborted();
    throw error;
  } finally {
    signal?.removeEventListener("abort", cancel);
    controller.signal.removeEventListener("abort", onAbort);
  }
}
