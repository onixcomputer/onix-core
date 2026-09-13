import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, writeFile, rm } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import branchfsExtension from "./extension/index.ts";

// Run with Pi -e live-check.ts --mode rpc --no-session. No model call occurs.
export default function liveCheck(pi: ExtensionAPI) {
  let tool;
  branchfsExtension({
    registerTool(definition) {
      tool = definition;
    },
    registerCommand() {},
    on() {},
    exec: (command, args, options) => pi.exec(command, args, options),
  } as unknown as ExtensionAPI);

  pi.on("session_start", async (_event, ctx) => {
    let root;
    try {
      assert.ok(
        pi.getAllTools().some((item) => item.name === "branchfs"),
        "Global BranchFS extension was not discovered.",
      );
      assert.ok(
        pi.getActiveTools().includes("branchfs"),
        "BranchFS tool is inactive.",
      );
      assert.ok(
        pi
          .getCommands()
          .some((item) => item.name === "skill:branchfs-workspaces"),
        "Global BranchFS skill was not discovered.",
      );
      root = await mkdtemp(join(homedir(), "pi-branchfs-live-"));
      const base = join(root, "base");
      const mount = join(root, "mount");
      const storage = join(root, "state");
      for (const path of [base, mount, storage]) await mkdir(path);
      const call = (action, extra = {}) =>
        tool.execute(
          "live-check",
          { action, base, mount, storage, ...extra },
          undefined,
        );
      await writeFile(join(base, "file"), "original");
      await assert.rejects(call("mount", { storage: base }), /separate trees/);
      await call("mount");
      await call("create", { name: "trial" });
      await writeFile(join(mount, "file"), "changed");
      assert.equal(await readFile(join(base, "file"), "utf8"), "original");
      await assert.rejects(call("abort"), /reviewed=true/);
      await call("abort", { reviewed: true });
      assert.equal(await readFile(join(mount, "file"), "utf8"), "original");
      await call("create", { name: "accepted" });
      await writeFile(join(mount, "new"), "accepted");
      await call("commit", { reviewed: true });
      assert.equal(await readFile(join(base, "new"), "utf8"), "accepted");
      await assert.rejects(
        call("abort", { reviewed: true }),
        /Cannot abort main branch/,
      );
      await call("unmount", { reviewed: true });
      await rm(root, { recursive: true });
      console.log(
        "PI_BRANCHFS_LIVE_PASS: discovery, isolation, abort, commit, overlap rejection, review rejection, main-abort rejection",
      );
    } catch (error) {
      console.error(
        `PI_BRANCHFS_LIVE_FAIL: ${String(error)}; retained workspace=${root ?? "none"}`,
      );
      process.exitCode = 1;
    } finally {
      ctx.shutdown();
    }
  });
}
