import assert from "node:assert/strict";
import { test } from "node:test";
import { mkdtemp, mkdir, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  ACTIONS,
  commandPlan,
  COMMAND_TIMEOUT_MS,
  overlaps,
} from "./extension/core.mjs";
import { canonicalPlan, runPlan } from "./extension/shell.mjs";

const mountInput = {
  action: "mount",
  base: "/base",
  mount: "/mount",
  storage: "/state",
};
test("accepted commands have explicit storage and no shell expansion", () => {
  assert.deepEqual(commandPlan(mountInput).args, [
    "mount",
    "--storage",
    "/state",
    "--base",
    "/base",
    "/mount",
  ]);
  for (const action of ACTIONS) {
    const plan = commandPlan({
      ...mountInput,
      action,
      name: "worker-a",
      reviewed: true,
    });
    assert.equal(plan.args[0], action);
    assert.ok(plan.args.includes("/state"));
  }
  assert.deepEqual(commandPlan({ action: "list", storage: "/state" }).paths, {
    storage: "/state",
  });
  assert.equal(overlaps("/base", "/base-other"), false);
});

test("reject malformed paths, overlaps, branch names, and unreviewed destructive actions", () => {
  const invalid = [
    undefined,
    { ...mountInput, action: "exec" },
    { ...mountInput, base: "/" },
    { ...mountInput, mount: "relative" },
    { ...mountInput, storage: "/base/state" },
    { ...mountInput, mount: "/base/child" },
    { ...mountInput, mount: "/state" },
    { ...mountInput, storage: "/bad\0path" },
    { ...mountInput, action: "create", name: "--help" },
    { ...mountInput, action: "create", name: "main" },
    { ...mountInput, action: "create", name: "a/b" },
    { ...mountInput, action: "create", name: "a", parent: "a;echo" },
    ...["commit", "abort", "unmount"].map((action) => ({
      ...mountInput,
      action,
    })),
  ];
  for (const input of invalid) assert.throws(() => commandPlan(input));
});

async function fixture(fn) {
  const root = await mkdtemp(join(tmpdir(), "pi-branchfs-test-"));
  const input = {
    action: "mount",
    base: join(root, "base"),
    mount: join(root, "mount"),
    storage: join(root, "state"),
  };
  try {
    for (const path of [input.base, input.mount, input.storage])
      await mkdir(path);
    await fn(input, root);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
}

test("adapter accepts empty directories and primary Git metadata", () =>
  fixture(async (input) => {
    await mkdir(join(input.base, ".git"));
    assert.deepEqual((await canonicalPlan(input)).paths, {
      storage: input.storage,
      mount: input.mount,
      base: input.base,
    });
  }));

test("adapter rejects linked Git and jj metadata", async () => {
  await fixture(async (input) => {
    await writeFile(
      join(input.base, ".git"),
      "gitdir: /other/repo/.git/worktrees/worker\n",
    );
    await assert.rejects(canonicalPlan(input), /linked Git worktree/);
  });
  await fixture(async (input) => {
    await mkdir(join(input.base, ".jj"));
    await assert.rejects(canonicalPlan(input), /jj workspace metadata/);
  });
});

test("adapter rejects nonempty state, absent paths, and canonical alias overlap", async () => {
  await fixture(async (input, root) => {
    await writeFile(join(input.storage, "existing"), "keep");
    await assert.rejects(canonicalPlan(input), /must be empty/);
    await assert.rejects(
      canonicalPlan({ ...input, base: join(root, "absent") }),
      /ENOENT/,
    );
  });
  await fixture(async (input, root) => {
    const alias = join(root, "alias");
    await symlink(input.base, alias);
    await assert.rejects(
      canonicalPlan({ ...input, mount: alias }),
      /separate trees/,
    );
  });
});

test("execution passes argv and deadline, reports errors, and honors cancellation", async () => {
  const plan = commandPlan({ action: "list", storage: "/state" });
  const signal = new AbortController().signal;
  const output = await runPlan(
    plan,
    async (cmd, args, options) => {
      assert.equal(cmd, "branchfs");
      assert.deepEqual(args, plan.args);
      assert.equal(options.timeout, COMMAND_TIMEOUT_MS);
      assert.equal(options.signal, signal);
      return { code: 0, stdout: "main", stderr: "", killed: false };
    },
    signal,
  );
  assert.equal(output, "main");
  await assert.rejects(
    runPlan(plan, async () => ({ code: 1, stderr: "denied" })),
    /denied/,
  );
  await assert.rejects(
    runPlan(plan, async () => ({ code: 0, killed: true })),
    /did not complete/,
  );
  const aborted = AbortSignal.abort();
  await assert.rejects(
    runPlan(plan, async () => assert.fail("must not execute"), aborted),
  );
});
