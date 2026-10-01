import { getBundledModels } from "@oh-my-pi/pi-ai";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import provider from "./provider.json";

// The Codex catalog seeded by the pinned Underclass revision. Copilot-only
// models use different request formats and are not advertised through this API.
const modelIds = [
  "gpt-5.4",
  "gpt-5.4-mini",
  "gpt-5.3-codex-spark",
  "gpt-5.5",
  "gpt-5.6-sol",
  "gpt-5.6-terra",
  "gpt-5.6-luna",
  "gpt-6-astra",
];

// r[impl onix.underclass.omp]
export default function underclass(pi: ExtensionAPI) {
  const models = getBundledModels("openai-codex")
    .filter((source) => modelIds.includes(source.id))
    .map((source) => {
      return {
        id: source.id,
        name: `${source.name} (Underclass)`,
        reasoning: source.reasoning,
        input: source.input,
        cost: source.cost,
        contextWindow: source.contextWindow,
        maxTokens: source.maxTokens,
        // Generic Responses otherwise sends an output cap that Codex rejects.
        // Underclass rewrites store=false, but does not remove output caps.
        omitMaxOutputTokens: true,
        compat: {
          supportsDeveloperRole: false,
          supportsReasoningSummary: source.compat.supportsReasoningSummary,
        },
      };
    });

  pi.registerProvider("underclass", {
    baseUrl: provider.baseUrl,
    apiKey: provider.apiKey,
    // SSE at /v1/responses, not Codex's /codex/responses or WebSocket route.
    // OMP's native transport supplies the conversation prompt_cache_key.
    api: "openai-responses",
    models,
  });
}
