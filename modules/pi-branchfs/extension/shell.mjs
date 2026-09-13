import { lstat, readdir, realpath, stat } from "node:fs/promises";
import { join } from "node:path";
import { commandPlan, COMMAND_TIMEOUT_MS } from "./core.mjs";

async function exists(path) {
  try {
    await lstat(path);
    return true;
  } catch (error) {
    if (error.code === "ENOENT") return false;
    throw error;
  }
}

export async function canonicalPlan(input) {
  const initial = commandPlan(input);
  const canonical = { ...input };
  for (const [name, path] of Object.entries(initial.paths)) {
    canonical[name] = await realpath(path);
    if (!(await stat(canonical[name])).isDirectory())
      throw new Error(`${name} must be a directory.`);
  }
  const plan = commandPlan(canonical);
  if (input.action === "mount") {
    for (const name of ["storage", "mount"]) {
      if ((await readdir(plan.paths[name])).length !== 0) {
        throw new Error(
          `${name} must be empty for a new mount. Existing state is not reused automatically.`,
        );
      }
    }
    const git = join(plan.paths.base, ".git");
    if (await exists(git)) {
      const marker = await lstat(git);
      if (!marker.isDirectory() || marker.isSymbolicLink()) {
        throw new Error(
          "A linked Git worktree or external Git directory is not an isolated base. Use the primary checkout.",
        );
      }
    }
    if (await exists(join(plan.paths.base, ".jj"))) {
      throw new Error(
        "jj workspace metadata needs repository-specific handling. Keep the required jj workspace workflow.",
      );
    }
  }
  return plan;
}

// The Pi adapter owns process execution and its mutation queue.
export async function runPlan(plan, exec, signal) {
  signal?.throwIfAborted();
  const result = await exec("branchfs", plan.args, {
    signal,
    timeout: COMMAND_TIMEOUT_MS,
  });
  if (result.killed || result.code !== 0) {
    throw new Error(
      `BranchFS did not complete. Inspect the mount and storage before retrying.\n${result.stderr || result.stdout}`,
    );
  }
  return result.stdout || "BranchFS command completed.";
}
