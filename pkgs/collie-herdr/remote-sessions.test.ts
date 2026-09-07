import { afterAll, describe, expect, test } from "bun:test";
import { mkdtemp, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { loadConfig } from "./config.ts";
import {
  hasLocalSessionFiles,
  parseRemoteSessionNames,
} from "./remote-sessions.ts";
import { startServer } from "./server.ts";

const HTTP_OK = 200;
const HTTP_NOT_FOUND = 404;
const HTTP_UNAVAILABLE = 501;
const EPHEMERAL_PORT = 0;
const PI_SESSION_FORMAT = 3;
const REMOTE = "aspen3";
const PANE = "w1:p1";
const LOCAL_CONTENT = "DESKTOP_JOURNAL_ONLY";

const root = await mkdtemp(join(tmpdir(), "collie-remote-test-"));
const journal = join(root, "session.jsonl");
await writeFile(
  journal,
  [
    JSON.stringify({
      type: "session",
      version: PI_SESSION_FORMAT,
      id: "019f1827-bf99-7927-9684-76318de905b5",
      cwd: "/repo",
    }),
    JSON.stringify({
      type: "message",
      id: "message",
      message: {
        role: "user",
        content: [{ type: "text", text: LOCAL_CONTENT }],
      },
    }),
  ].join("\n"),
);

const cfg = {
  ...loadConfig(),
  host: "127.0.0.1",
  port: EPHEMERAL_PORT,
  transcript: true,
  remoteSessions: [REMOTE],
  stateDir: root,
  journalRoots: { claude: root, codex: root, pi: root, opencode: root },
};
const calls: string[] = [];
const pane = {
  paneId: PANE,
  workspaceId: "w1",
  workspaceLabel: "fixture",
  workspaceNumber: 1,
  tabId: "w1:t1",
  agent: "pi",
  status: "idle",
  cwd: "/repo",
  focused: false,
  agentSession: { agent: "pi", kind: "path", value: journal },
};
const runtime = (name: string) => ({
  name,
  engine: {
    current: () => ({
      bridge: "connected",
      agents: [pane],
      shellPanes: [],
      workspaces: [],
      tabs: [],
    }),
  },
  herdr: {
    readPane: async () => ({
      pane_id: PANE,
      text: `${name}-terminal`,
      revision: 1,
      truncated: false,
    }),
    sendPaneText: async (_pane: string, text: string) => {
      calls.push(`${name}:${text}`);
    },
    sendPaneKeys: async () => {},
  },
});
const local = runtime("default");
const remote = runtime(REMOTE);
const options = {
  cfg,
  registry: {
    get: (name?: string) =>
      !name || name === "default"
        ? local
        : name === REMOTE
          ? remote
          : undefined,
    list: () => [],
  },
  push: {},
  snooze: { until: () => null },
  notifyPrefs: {},
  updateMonitor: { status: () => ({}) },
  audit: { record: () => {} },
  activity: { get: () => undefined, noteSeen: () => {} },
} as unknown as Parameters<typeof startServer>[0];
const server = startServer(options);
const base = `http://127.0.0.1:${server.port}`;
afterAll(async () => {
  await server.stop(true);
  await rm(root, { recursive: true, force: true });
});

async function get(path: string) {
  return fetch(`${base}${path}`);
}

describe("remote session policy", () => {
  test("accepts absent configuration and explicit unique names", () => {
    expect(parseRemoteSessionNames(undefined)).toEqual([]);
    expect(parseRemoteSessionNames(" ")).toEqual([]);
    expect(parseRemoteSessionNames("aspen3, aspen3-work")).toEqual([
      REMOTE,
      "aspen3-work",
    ]);
    expect(hasLocalSessionFiles("default", [REMOTE])).toBe(true);
    expect(hasLocalSessionFiles("local-work", [REMOTE])).toBe(true);
    expect(hasLocalSessionFiles(REMOTE, [REMOTE])).toBe(false);
  });
  test.each([
    "default",
    "../aspen3",
    "/tmp/socket",
    "aspen3,",
    "aspen3,aspen3",
    "aspen 3",
  ])("rejects %s", (value) => {
    expect(() => parseRemoteSessionNames(value)).toThrow();
  });
});

describe("cross-host request routing", () => {
  test("identical pane IDs keep their selected host for reads and replies", async () => {
    const localReply = await (await get(`/api/pane/${PANE}`)).json();
    const remoteReply = await (
      await get(`/api/pane/${PANE}?session=${REMOTE}`)
    ).json();
    expect(localReply.text).toBe("default-terminal");
    expect(remoteReply.text).toBe("aspen3-terminal");
    const reply = await fetch(
      `${base}/api/pane/${PANE}/reply?session=${REMOTE}`,
      {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ text: "remote-only", submit: false }),
      },
    );
    expect(reply.status).toBe(HTTP_OK);
    expect(await reply.json()).toEqual({ ok: true });
    expect(calls).toEqual(["aspen3:remote-only"]);
  });
  test("unknown sessions never fall back to the primary", async () => {
    const before = [...calls];
    const reply = await fetch(
      `${base}/api/pane/${PANE}/reply?session=missing`,
      {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ text: "must-not-send" }),
      },
    );
    expect(reply.status).toBe(HTTP_NOT_FOUND);
    expect(calls).toEqual(before);
  });
  test("remote snapshots do not advertise local journal access", async () => {
    const localSnapshot = await (await get("/api/snapshot")).json();
    const remoteSnapshot = await (
      await get(`/api/snapshot?session=${REMOTE}`)
    ).json();
    expect(localSnapshot.agents[0].hasSession).toBe(true);
    expect(remoteSnapshot.agents[0].hasSession).toBeUndefined();
  });
  test("remote history cannot read the same-path desktop journal", async () => {
    const localHistory = await (await get(`/api/pane/${PANE}/history`)).json();
    expect(localHistory.available).toBe(true);
    expect(JSON.stringify(localHistory)).toContain(LOCAL_CONTENT);
    const remoteHistory = await (
      await get(`/api/pane/${PANE}/history?session=${REMOTE}`)
    ).json();
    expect(remoteHistory).toEqual({
      paneId: PANE,
      available: false,
      reason: "disabled",
    });
    expect(await readFile(journal, "utf8")).toContain(LOCAL_CONTENT);
  });
  test("remote uploads fail before any local file write", async () => {
    const before = await readdir(root);
    const data = new FormData();
    data.append(
      "file",
      new Blob(["fixture"], { type: "image/png" }),
      "fixture.png",
    );
    const reply = await fetch(
      `${base}/api/pane/${PANE}/upload?session=${REMOTE}`,
      { method: "POST", body: data },
    );
    expect(reply.status).toBe(HTTP_UNAVAILABLE);
    expect(await readdir(root)).toEqual(before);
  });
});
