import { isAbsolute, normalize, relative } from "node:path";

export const COMMAND_TIMEOUT_MS = 120_000;
export const ACTIONS = [
  "mount",
  "create",
  "list",
  "commit",
  "abort",
  "unmount",
];
const MAX_BRANCH_NAME_LENGTH = 64;
const BRANCH_NAME = /^[a-zA-Z0-9][a-zA-Z0-9_-]*$/;

export const GUIDANCE =
  "Prefer branchfs for temporary isolated edits and parallel agent work instead of new Git worktrees or jj workspaces. Read the branchfs-workspaces skill first. Preserve explicit repository worktree requirements. Use absolute mount paths for file tools and an explicit mount cwd for commands. BranchFS does not change Pi or Pueue cwd. Do not commit or discard until all workers stop. Do not treat BranchFS as a security boundary or assume that it detects base conflicts.";

function absolutePath(value, name) {
  if (typeof value !== "string" || !isAbsolute(value) || value.includes("\0")) {
    throw new Error(`${name} must be an absolute path.`);
  }
  const result = normalize(value);
  if (result === "/")
    throw new Error(`${name} must not be the filesystem root.`);
  return result;
}

export function overlaps(left, right) {
  const inside = (base, child) => {
    const delta = relative(base, child);
    return (
      delta === "" ||
      (delta !== ".." && !delta.startsWith("../") && !isAbsolute(delta))
    );
  };
  return inside(left, right) || inside(right, left);
}

function branchName(value, name) {
  if (
    typeof value !== "string" ||
    value.length > MAX_BRANCH_NAME_LENGTH ||
    !BRANCH_NAME.test(value)
  ) {
    throw new Error(
      `${name} must contain only letters, digits, underscores, or hyphens and start with a letter or digit.`,
    );
  }
  return value;
}

// Pure CLI policy. The adapter supplies canonical paths before execution.
export function commandPlan(input) {
  if (!input || !ACTIONS.includes(input.action))
    throw new Error("Unknown BranchFS action.");
  const storage = absolutePath(input.storage, "storage");
  const args = [input.action, "--storage", storage];
  if (input.action === "list") return { args, paths: { storage } };
  const mount = absolutePath(input.mount, "mount");
  if (overlaps(storage, mount))
    throw new Error("Storage and mount must be separate trees.");
  if (
    ["commit", "abort", "unmount"].includes(input.action) &&
    input.reviewed !== true
  ) {
    throw new Error(
      "Review the affected workspace and stop its workers, then set reviewed=true.",
    );
  }
  if (input.action === "mount") {
    const base = absolutePath(input.base, "base");
    if (overlaps(base, mount) || overlaps(base, storage)) {
      throw new Error("Base, storage, and mount must be separate trees.");
    }
    args.push("--base", base, mount);
    return { args, paths: { storage, mount, base } };
  }
  if (input.action === "create") {
    const name = branchName(input.name, "name");
    if (name === "main") throw new Error("The main branch is reserved.");
    args.push(name, "--parent", branchName(input.parent ?? "main", "parent"));
  }
  args.push(mount);
  return { args, paths: { storage, mount } };
}
