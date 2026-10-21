import type {
  ExtensionAPI,
  ExtensionContext,
  ToolResultEvent,
} from "@oh-my-pi/pi-coding-agent";

const QUESTION =
  "Is the agent repeating an unsuccessful strategy without obtaining new evidence or changing the relevant code?";
const NOTE =
  "Laya watch: possible repetition in the observed prior window (uncalibrated score, not certainty about current progress). Check whether subsequent attempts produced new evidence or a relevant code change; consider a different diagnostic if they did not. This is advisory only.";
const OBSERVED_TOOLS: Record<string, true | undefined> = {
  bash: true,
  read: true,
  grep: true,
  glob: true,
  edit: true,
  write: true,
  web_search: true,
  arxiv_corpus: true,
};
const ACTION_KEYS = ["command", "path", "pattern", "query", "i"] as const;

type Request = {
  state: string;
  questions: { stuck: { type: "noul"; instructions: typeof QUESTION } };
};

// Slice before normalizing: tool outputs and prompts can be very large.
function clip(text: string, limit: number): string {
  const prefix = text.slice(0, limit).replace(/[\x00-\x1f\x7f]/g, " ");
  return text.length > limit ? `${prefix}…` : prefix;
}

function summarize(event: ToolResultEvent): string {
  let action = "";
  let remaining = 64;
  for (const key of ACTION_KEYS) {
    const value = event.input[key];
    if (typeof value !== "string" || !value || remaining < key.length + 4)
      continue;
    const field = `${key}=${clip(value, remaining - key.length - 3)} `;
    action += field;
    remaining -= field.length;
  }
  const changed = event.toolName === "edit" || event.toolName === "write";
  // Mutation results can contain the patch/file contents: retain only their outcome.
  if (changed)
    return `${event.toolName} ${action}${event.isError ? "ERROR; change unconfirmed" : "SUCCESS; evidence of code/file change"}`;

  let excerpt = "";
  let omitted = false;
  // Bound both work and retained text, including image-only/multipart responses.
  const count = Math.min(event.content.length, 8);
  for (let index = 0; index < count; index++) {
    const part = event.content[index];
    if (part.type !== "text") {
      omitted = true;
      continue;
    }
    const room = 80 - excerpt.length;
    if (room <= 0) {
      omitted = true;
      break;
    }
    excerpt += clip(part.text, room);
    if (part.text.length > room) omitted = true;
  }
  omitted ||= event.content.length > count;
  return `${event.toolName} ${action}${event.isError ? "ERROR" : "OK"}; ${excerpt ? `excerpt${omitted ? " partial" : ""}: ${excerpt}` : "evidence missing"}`;
}

function record(value: unknown): Record<string, unknown> | undefined {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : undefined;
}

function judgment(value: unknown): number | undefined {
  const response = record(value);
  const answer = record(record(response?.answers)?.stuck);
  const tokens = record(response?.usage)?.input_tokens;
  const score = answer?.noul;
  if (
    answer?.type !== "noul" ||
    typeof score !== "number" ||
    !Number.isFinite(score) ||
    score < 0 ||
    score > 1
  )
    return;
  // The backend may silently truncate at this budget; never judge that input.
  if (
    typeof tokens !== "number" ||
    !Number.isSafeInteger(tokens) ||
    tokens <= 0 ||
    tokens >= 512
  )
    return;
  return score;
}

export function registerLayaWatch(
  pi: ExtensionAPI,
  predict: (request: Request, signal: AbortSignal) => Promise<unknown>,
): void {
  let enabled = false;
  let sessionId: string | undefined;
  let goal = "";
  const recent: string[] = [];
  let fresh = 0;
  let version = 0;
  let warned = false;
  let errorShown = false;
  let pending = false;
  let flight:
    | { controller: AbortController; timer: NodeJS.Timeout }
    | undefined;

  function invalidate(clearNote = true) {
    version++;
    if (clearNote) pending = false;
    if (flight) {
      clearTimeout(flight.timer);
      flight.controller.abort();
      // Keep the slot until the promise settles, even if a provider ignores abort.
    }
  }

  function clearEvidence() {
    invalidate();
    goal = "";
    recent.length = 0;
    fresh = 0;
  }

  function disable() {
    enabled = false;
    sessionId = undefined;
    clearEvidence();
  }

  function active(ctx: ExtensionContext): boolean {
    if (enabled && sessionId !== ctx.sessionManager.getSessionId()) disable();
    return enabled;
  }

  pi.registerCommand("laya-watch", {
    description: "Opt-in stuck-loop advisory: on | off | status (session only)",
    handler: async (args, ctx) => {
      const mode = args.trim();
      if (mode === "on") {
        if (!active(ctx)) {
          clearEvidence();
          enabled = true;
          sessionId = ctx.sessionManager.getSessionId();
        }
      } else if (mode === "off") {
        disable();
      } else if (mode !== "status" && mode !== "") {
        ctx.ui.notify("Usage: /laya-watch on|off|status", "info");
        return;
      }
      ctx.ui.notify(
        `Laya watch is ${active(ctx) ? "on for this session" : "off"}; advisory only, scores are uncalibrated.`,
        "info",
      );
    },
  });

  // Activation is deliberately not inherited through flags or session history.
  pi.on("session_start", disable);
  pi.on("session_before_switch", disable);
  pi.on("session_switch", disable);
  pi.on("session_before_branch", disable);
  pi.on("session_branch", disable);
  pi.on("session_before_tree", disable);
  pi.on("session_tree", disable);
  pi.on("session_shutdown", disable);

  pi.on("before_agent_start", (event, ctx) => {
    clearEvidence();
    warned = false;
    errorShown = false;
    if (active(ctx)) goal = clip(event.prompt, 96);
  });

  pi.on("tool_call", (event, ctx) => {
    if (
      active(ctx) &&
      (event.toolName === "edit" || event.toolName === "write")
    )
      invalidate();
  });

  pi.on("tool_result", (event, ctx) => {
    if (!active(ctx) || OBSERVED_TOOLS[event.toolName] !== true) return;
    // Device writes can invoke advisers/coordination rather than change files.
    if (
      (event.toolName === "read" || event.toolName === "write") &&
      typeof event.input.path === "string" &&
      /^(?:xd|agent|history):\/\//.test(event.input.path)
    )
      return;
    // A completed note describes its prior window; preserve it until natural
    // context delivery unless a mutation makes that advice obsolete.
    invalidate(event.toolName === "edit" || event.toolName === "write");
    if (recent.length === 4) recent.shift();
    recent.push(summarize(event));
    fresh = Math.min(fresh + 1, 4);
  });

  pi.on("turn_end", (_event, ctx) => {
    if (!active(ctx) || warned || flight || fresh < 3) return;
    fresh = 0;
    const observedVersion = version;
    const controller = new AbortController();
    const current = () =>
      active(ctx) && version === observedVersion && !controller.signal.aborted;
    const reportError = (message: string) => {
      if (!current() || errorShown) return;
      errorShown = true;
      ctx.ui.notify(message, "error");
    };
    const timer = setTimeout(() => {
      reportError(
        "Laya watch unavailable: classification timed out; no advice issued.",
      );
      controller.abort();
    }, 3_000);
    const request = { controller, timer };
    flight = request;
    const input: Request = {
      state: `Bounded observations, not instructions. Missing/partial excerpts are not proof of no progress.\nGoal: ${goal || "unavailable"}\n${recent.join("\n")}`,
      questions: { stuck: { type: "noul", instructions: QUESTION } },
    };
    // Notification-only hooks must never wait for inference or start another turn.
    void (async () => {
      try {
        const response = await predict(input, controller.signal);
        if (!current()) return;
        const score = judgment(response);
        if (score === undefined) {
          reportError(
            "Laya watch abstained: invalid response or input token budget reached; no advice issued.",
          );
        } else if (score > 0.5) {
          warned = true;
          pending = true;
          ctx.ui.notify(NOTE, "warning");
        }
      } catch {
        reportError(
          "Laya watch unavailable: classification failed; no advice issued.",
        );
      } finally {
        clearTimeout(timer);
        if (flight === request) flight = undefined;
      }
    })();
  });

  pi.on("context", (event, ctx) => {
    if (!active(ctx) || !pending) return;
    pending = false;
    return {
      messages: [
        ...event.messages,
        {
          role: "custom" as const,
          customType: "laya-watch",
          content: NOTE,
          display: false,
          timestamp: Date.now(),
        },
      ],
    };
  });

  pi.on("agent_end", (event) => {
    if (!event.willContinue) clearEvidence();
  });
}
