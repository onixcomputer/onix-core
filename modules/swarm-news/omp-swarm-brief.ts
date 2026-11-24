// Swarm brief for OMP: before the first prompt of each main session, and again
// after /clear, add the swarm's open claims and latest announcements to the
// model's context. Subagents and advisors get nothing.
import { execFile } from "node:child_process";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const BRIEF = "@brief@";

function readBrief(): Promise<string> {
  const { promise, resolve } = Promise.withResolvers<string>();
  execFile(
    BRIEF,
    [],
    { timeout: 20_000, maxBuffer: 256 * 1024 },
    (error, stdout) => {
      resolve(error ? "" : String(stdout).trim());
    },
  );
  return promise;
}

export default function swarmBrief(pi: ExtensionAPI) {
  pi.setLabel("Swarm brief");
  let pending: Promise<string> | undefined;
  let delivered = false;

  // Start reading while the operator types the first prompt.
  pi.on("session_start", async (_event, ctx) => {
    if ((ctx.agent?.kind ?? "main") === "main") pending = readBrief();
  });

  pi.on("session_clear", async () => {
    delivered = false;
    pending = undefined;
  });

  pi.on("before_agent_start", async (event, ctx) => {
    if ((ctx.agent?.kind ?? "main") !== "main" || delivered) return;
    if (event.reason !== undefined && event.reason !== "prompt") return;
    delivered = true;
    const text = await (pending ?? readBrief());
    pending = undefined;
    if (!text) return;
    return {
      message: {
        customType: "swarm-brief",
        content: text,
        display: false,
        attribution: "agent",
      },
    };
  });
}
