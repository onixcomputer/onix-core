#!/usr/bin/env python3
"""Smoke test for the served 1017 deployment (run on the head, after boot)."""
import json
import sys
import time
import urllib.request

BASE = "http://localhost:8888"
MODEL = "deepseek-v4.1-flash"


def post(path, payload, timeout=900):
    req = urllib.request.Request(BASE + path, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=timeout) as r:
        out = json.load(r)
    return out, time.time() - t0


def chat(content, max_tokens=64, temperature=0.0, timeout=900):
    out, dt = post("/v1/chat/completions", {
        "model": MODEL, "messages": [{"role": "user", "content": content}],
        "max_tokens": max_tokens, "temperature": temperature}, timeout)
    msg = out["choices"][0]["message"]
    return msg.get("content") or "", msg.get("reasoning_content") or "", dt, out.get("usage", {})


def main() -> int:
    with urllib.request.urlopen(BASE + "/v1/models", timeout=30) as r:
        models = json.load(r)
    print("models:", [m["id"] for m in models["data"]])

    for prompt, want in (("Reply with the single word: ready", "ready"),
                         ("What is 84 * 3 / 2? Answer with the number only.", "126")):
        text, reasoning, dt, usage = chat(prompt, max_tokens=64)
        print(f"Q: {prompt!r}\nA: {text!r} (reasoning {len(reasoning)} chars) "
              f"{dt:.1f}s usage={usage.get('completion_tokens')}")
        assert want in text, (prompt, text)

    # Long-context needle: exercises sparse MLA, the compressed indexer and the
    # on-disk Engram tables (layers 1 and 14 read their rows from NVMe).
    key = "Q7X-4421"
    filler = ("The quarterly logistics report covers warehouse throughput, pallet "
              "rotation and the reconciliation of inbound manifests. ")
    body = filler * 3500
    half = len(body) // 2
    prompt = ("Read the report below and answer the question at the end.\n\n"
              f"{body[:half]}\nIMPORTANT: the access code is {key}.\n{body[half:]}\n\n"
              "Question: what is the access code? Reply with the code only.")
    text, reasoning, dt, usage = chat(prompt, max_tokens=64)
    print(f"needle (~{usage.get('prompt_tokens')} prompt tokens): {text!r} in {dt:.1f}s")
    assert key in text, text
    print("SMOKE OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
