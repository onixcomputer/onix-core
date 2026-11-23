// Import the bundled catalog from pi-ai: older fleet OMP releases do not
// export @oh-my-pi/pi-catalog/models.
import { getBundledModels } from "@oh-my-pi/pi-ai";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import provider from "./provider.json";

interface CatalogModel {
  id: string;
  name: string;
  owned_by: string;
  context_window: number;
  max_output_tokens: number;
}

/** Underclass catalogs OpenCode Go models under this namespace (its ADR 0027). */
const OPENCODE_GO_NAMESPACE = "opencode-go/";
const NO_COST = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 };

// r[impl onix.underclass.omp]
export default function underclass(pi: ExtensionAPI) {
  const codexMetadata = new Map(
    [...getBundledModels("openai"), ...getBundledModels("openai-codex")].map(
      (model) => [model.id, model] as const,
    ),
  );
  const goMetadata = new Map(
    getBundledModels("opencode-go").map((model) => [model.id, model] as const),
  );

  const claudeMetadata = new Map(
    getBundledModels("anthropic").map((model) => [model.id, model] as const),
  );
  const CLAUDE_CODE_VERSION = "2.1.290";
  const claudeHeaders = {
    "x-app": "cli",
    "User-Agent": `claude-cli/${CLAUDE_CODE_VERSION}`,
    "anthropic-beta": "claude-code-20250219",
  };

  const codexModel = (model: CatalogModel) => {
    const source = codexMetadata.get(model.id);
    const input: ("text" | "image")[] = source?.input ?? ["text"];
    return {
      id: model.id,
      name: `${model.name} (Underclass)`,
      reasoning: source?.reasoning ?? false,
      thinking: source?.thinking,
      input,
      cost: source?.cost ?? NO_COST,
      contextWindow: model.context_window,
      maxTokens: model.max_output_tokens,
      // Codex rejects the generic Responses output-token cap.
      omitMaxOutputTokens: true,
      compat: {
        supportsDeveloperRole: false,
        supportsReasoningSummary:
          source?.compat.supportsReasoningSummary ?? false,
      },
    };
  };

  const goModel = (model: CatalogModel) => {
    const source = goMetadata.get(model.id.slice(OPENCODE_GO_NAMESPACE.length));
    // Underclass serves only the OpenAI surface. The gateway translates models whose own API
    // is Anthropic Messages or Gemini from Chat Completions.
    const api =
      source?.api === "openai-responses"
        ? "openai-responses"
        : "openai-completions";
    // The request reaches the same gateway as OMP's native opencode-go provider, so the native
    // request shaping applies when the native API is the one used here.
    const sameApi = source?.api === api;
    const input: ("text" | "image")[] = source?.input ?? ["text"];
    return {
      id: model.id,
      name: `${model.name} (Underclass Go)`,
      api,
      reasoning: source?.reasoning ?? false,
      thinking:
        sameApi || source?.thinking?.mode === "effort"
          ? source?.thinking
          : undefined,
      input,
      cost: source?.cost ?? NO_COST,
      contextWindow: model.context_window,
      maxTokens: model.max_output_tokens,
      compat: {
        ...(sameApi
          ? source.compat
          : { supportsDeveloperRole: false, supportsStore: false }),
        // Underclass pins the conversation to one account by this key and forwards it to
        // OpenCode Go as x-opencode-session.
        supportsPromptCacheKey: true,
      },
    };
  };

  // r[impl onix.underclass.claude_omp]
  // Underclass serves Claude Code subscriptions on the Anthropic Messages surface only.
  const claudeModel = (model: CatalogModel) => {
    const source = claudeMetadata.get(model.id);
    return {
      id: model.id,
      name: `${model.name} (Underclass Claude)`,
      api: "anthropic-messages" as const,
      reasoning: source?.reasoning ?? true,
      thinking: source?.thinking,
      input: source?.input ?? (["text", "image"] as ("text" | "image")[]),
      cost: source?.cost ?? NO_COST,
      contextWindow: model.context_window,
      maxTokens: model.max_output_tokens,
      headers: claudeHeaders,
      compat: source?.compat,
    };
  };

  pi.registerProvider("underclass", {
    baseUrl: provider.baseUrl,
    apiKey: provider.apiKey,
    // Codex models: SSE at /v1/responses, not Codex's /codex/responses or WebSocket route.
    // OMP's native transport supplies the conversation prompt_cache_key. OpenCode Go models
    // name their own API.
    api: "openai-responses",
    // r[impl onix.underclass.claude_omp]
    fetchDynamicModels: async (apiKey) => {
      if (!apiKey)
        throw new Error("Underclass model discovery requires a proxy key");
      const response = await fetch(`${provider.baseUrl}/models`, {
        headers: { Authorization: `Bearer ${apiKey}` },
      });
      if (!response.ok) {
        throw new Error(
          `Underclass model discovery failed: HTTP ${response.status}`,
        );
      }
      const catalog = (await response.json()) as { data: CatalogModel[] };
      // Copilot models are not served through this provider.
      return catalog.data.flatMap((model) => {
        if (model.owned_by === "underclass-codex") return [codexModel(model)];
        if (model.owned_by === "underclass-claude") return [claudeModel(model)];
        if (
          model.owned_by === "underclass-opencode-go" &&
          model.id.startsWith(OPENCODE_GO_NAMESPACE)
        ) {
          return [goModel(model)];
        }
        return [];
      });
    },
  });

  // Underclass's Claude backend admits only the official Claude Code client: it
  // requires the identity block in the request's system prompt (and the Claude
  // Code headers above). Prepend the identity to Anthropic-surface requests.
  // r[impl onix.underclass.claude_omp]
  pi.on("before_provider_request", (event, ctx) => {
    const model = ctx.model;
    if (model.provider !== "underclass" || model.api !== "anthropic-messages") return;
    const payload = event.payload as Record<string, unknown>;
    const identity = {
      type: "text",
      text: "You are Claude Code, Anthropic's official CLI for Claude.",
    };
    const system = payload.system;
    if (Array.isArray(system)) {
      payload.system = [identity, ...system];
    } else if (typeof system === "string" && system.length > 0) {
      payload.system = [identity, { type: "text", text: system }];
    } else {
      payload.system = [identity];
    }
    return payload;
  });
}
