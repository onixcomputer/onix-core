import { Type, StringEnum } from "@earendil-works/pi-ai";
import {
  truncateTail,
  withFileMutationQueue,
  type ExtensionAPI,
} from "@earendil-works/pi-coding-agent";
import { ACTIONS, commandPlan, GUIDANCE } from "./core.mjs";
import { canonicalPlan, runPlan } from "./shell.mjs";

export default function branchfsExtension(pi: ExtensionAPI) {
  pi.registerTool({
    name: "branchfs",
    label: "BranchFS workspace",
    description:
      "Manage an explicit BranchFS workspace instead of a temporary worktree. All paths must be absolute existing directories. Mount requires empty mount and storage directories outside the base. Commit writes into the parent. Abort and unmount can discard work. Output uses Pi truncation limits.",
    promptSnippet:
      "Mount, create, inspect, commit, abort, or unmount a BranchFS workspace.",
    promptGuidelines: [GUIDANCE],
    parameters: Type.Object({
      action: StringEnum(ACTIONS),
      storage: Type.String({
        description:
          "Dedicated state directory. Use the same path for every workspace command.",
      }),
      mount: Type.Optional(
        Type.String({
          description: "Mount directory. Required except for list.",
        }),
      ),
      base: Type.Optional(
        Type.String({ description: "Source directory, required for mount." }),
      ),
      name: Type.Optional(
        Type.String({ description: "New branch name, required for create." }),
      ),
      parent: Type.Optional(
        Type.String({
          description: "Parent branch for create. Defaults to main.",
        }),
      ),
      reviewed: Type.Optional(
        Type.Boolean({
          description:
            "Confirm scope review and stopped workers for commit, abort, or unmount. This is not an authorization grant.",
        }),
      ),
    }),
    async execute(_id, params, signal) {
      // Reject malformed input before filesystem access.
      commandPlan(params);
      const initial = await canonicalPlan(params);
      return withFileMutationQueue(initial.paths.storage, async () => {
        // Recheck mutable state after earlier commands on this storage finish.
        const plan = await canonicalPlan(params);
        try {
          const output = await runPlan(
            plan,
            (command, args, options) => pi.exec(command, args, options),
            signal,
          );
          const text = truncateTail(output);
          return {
            content: [
              {
                type: "text",
                text:
                  text.content +
                  (text.truncated ? "\n[BranchFS output truncated.]" : ""),
              },
            ],
            details: { action: params.action, ...plan.paths },
          };
        } catch (error) {
          throw new Error(truncateTail(String(error)).content);
        }
      });
    },
  });
  pi.registerCommand("branchfs-status", {
    description: "Show the BranchFS workspace default and skill command.",
    handler: async (_args, ctx) => {
      const active = pi.getActiveTools().includes("branchfs");
      ctx.ui.notify(
        `BranchFS tool ${active ? "active" : "inactive"}. Use /skill:branchfs-workspaces. Existing mounts remain unchanged.`,
        "info",
      );
    },
  });
  pi.on("before_agent_start", (event) => ({
    systemPrompt: `${event.systemPrompt}\n\nBranchFS workspace default: ${GUIDANCE}`,
  }));
}
