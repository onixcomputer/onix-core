const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const test = require("node:test");
const source = fs.readFileSync(process.env.KAGI_UNLOCK_SCRIPT, "utf8");
const FIXTURE_TOKEN = "fixture-engine-token";
const FIXTURE_NONCE = "fixture-form-nonce";

function harness(mode = "saved", present = true) {
  const clicks = {};
  const submits = {};
  const calls = [];
  const navigations = [];
  const timers = [];
  const feedback = { textContent: "" };
  const button = {
    disabled: false,
    addEventListener: (name, fn) => {
      clicks[name] = fn;
    },
  };
  const form = {
    getAttribute: (name) =>
      name === "action" ? "/kagi-access" : "/preferences",
    addEventListener: (name, fn) => {
      submits[name] = fn;
    },
    querySelector: (selector) =>
      selector.startsWith("button")
        ? button
        : {
            value: selector.includes("kagi_engine_token")
              ? FIXTURE_TOKEN
              : FIXTURE_NONCE,
          },
  };
  const context = {
    document: {
      querySelector: (selector) =>
        selector.endsWith(" form") ? (present ? form : null) : feedback,
    },
    location: {
      href: "https://search.example/preferences",
      assign: (url) => navigations.push(url),
    },
    URL,
    URLSearchParams,
    AbortController,
    setTimeout: (fn) => {
      timers.push(fn);
      return timers.length;
    },
    clearTimeout: () => {},
    fetch: async (url, options) => {
      calls.push({ url, options });
      if (mode === "network") throw new Error("offline");
      if (mode === "timeout")
        return new Promise((resolve, reject) =>
          options.signal.addEventListener("abort", () =>
            reject(new Error("aborted")),
          ),
        );
      return {
        ok: mode !== "http-error",
        json: async () => ({ outcome: mode }),
      };
    },
  };
  vm.runInNewContext(source, context);
  return { clicks, submits, calls, navigations, timers, feedback, button };
}

const event = { preventDefault() {} };

test("click and submit send only a same-origin POST then navigate by outcome", async () => {
  for (const outcome of ["saved", "rejected"]) {
    const h = harness(outcome);
    await h.clicks.click(event);
    assert.equal(h.calls.length, 1);
    const call = h.calls[0];
    assert.equal(call.options.method, "POST");
    assert.equal(call.options.credentials, "same-origin");
    assert.equal(call.options.headers.Accept, "application/json");
    const body = new URLSearchParams(call.options.body);
    assert.equal(body.get("kagi_engine_token"), FIXTURE_TOKEN);
    assert.equal(body.get("kagi_form_nonce"), FIXTURE_NONCE);
    assert.equal(
      h.navigations[0],
      "https://search.example/preferences?kagi_unlock=" + outcome,
    );
    assert.equal(h.submits.submit, h.clicks.click);
    assert.equal(h.feedback.textContent.includes(FIXTURE_TOKEN), false);
  }
});

test("network, HTTP, and unknown outcomes never navigate or echo tokens", async () => {
  for (const mode of ["network", "http-error", "unexpected"]) {
    const h = harness(mode);
    await h.clicks.click(event);
    assert.equal(h.navigations.length, 0);
    assert.match(h.feedback.textContent, /Unlock failed/);
    assert.equal(h.feedback.textContent.includes(FIXTURE_TOKEN), false);
    assert.equal(h.button.disabled, false);
  }
});

test("timeout aborts the request and a duplicate click does not submit again", async () => {
  const h = harness("timeout");
  const pending = h.clicks.click(event);
  await h.clicks.click(event);
  assert.equal(h.calls.length, 1);
  h.timers[0]();
  await pending;
  assert.equal(h.calls[0].options.signal.aborted, true);
  assert.equal(h.navigations.length, 0);
  assert.match(h.feedback.textContent, /Unlock failed/);
});

test("pages without the form have no event handlers or requests", () => {
  const h = harness("saved", false);
  assert.equal(h.calls.length, 0);
  assert.equal(h.clicks.click, undefined);
});
