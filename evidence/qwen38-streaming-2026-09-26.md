# Qwen3.8 streaming and aspen3 /tmp (2026-09-26)

## Qwen3.8 P150x2 streaming

omp sent `"stream": true` to `mesh/Qwen3.8-27B` and the service answered
`400 streaming responses are not supported`.

- tenstorrent.nix `a7d31eb` ("Stream Qwen3.8 completions as server-sent events")
  adds SSE to both completion routes, `stream_options.include_usage`, and chat
  content given as text parts. `probe_streaming` and the updated request-contract
  probe pass device-free and in the `qwen38` package build.
- onix-core `f9dbdeef` moves `tenstorrent-nix-qwen` to `a7d31eb`.
- britton-desktop generation 865:
  `/nix/store/xsxrd8450mg9aqbngnspncv6mikij7lr-nixos-system-britton-desktop-26.11.20260908.e9b9cbe`,
  package `/nix/store/bkvh730j6vysg89nmnqgx9f6nwkxyph3-qwen38-0.1.0`.
  Only the `qwen38-p150x2.service` ExecStart changed. The service came back
  ready 991 s after activation (`masked-prefill-traces-captured` at 694 s,
  warm-up for widths 1 and 4 at 856 s).

Measured on hardware (chat request, 48 tokens, greedy, content given as two text parts):

| Path | Status | Content chunks | First delta | Last delta | Finish | Usage chunk | `[DONE]` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `127.0.0.1:8000` direct | 200 `text/event-stream` | 48 | 0.321 s | 3.009 s | `length` | 64 + 48 tokens | yes |
| `127.0.0.1:9337` mesh-llm | 200 `text/event-stream` | 48 | 0.546 s | 3.303 s | `length` | 64 + 48 tokens | yes |

Non-streaming requests still return `chat.completion` JSON (23.5 tok/s decode).
`/v1/systemone` still answers (masked-trace route, 234 ms).

omp still cannot use this model with its default prompt. Its minimal request
needs 5,810 tokens, and the service limit is 2,048 (`ADMITTED_MAX_SEQUENCE_LENGTH`).
The service now rejects that request with a JSON 400 that states the limit,
instead of rejecting the stream.

## aspen3 /tmp

`/tmp` (61 GB tmpfs) was full, so Lemonade could not load models
(`LLVM ERROR: IO failure on output stream: No space left on device`).

- Audit: 5,148 entries. Each entry was checked for its newest mtime and for
  references from any process's cwd, command line or open files.
- Removed 85 entries of 10 MiB or more whose newest file was at least 24 h old
  and which no process referenced. These were `noble-m6-*`, `noble-m7-*` and
  `molten-node-*` build and test trees, 49.3 GiB in total. Each entry was
  re-checked just before its removal.
- Kept: `nanokvm-ramboot-PNh8Wj` (11 GiB, in use), `lemonade-server.log`,
  live `omp-worker-stderr-*` files and every small entry.
- After: 12 G used, 50 G free (19%).

Through the desktop mesh (`127.0.0.1:9337`), after the cleanup:

- `user.VibeThinker-3B`: answered, 8.1 s.
- `user.Qwen3.6-35B-A3B`: `finish_reason` `stop`, content `ok`, 134 completion
  tokens including reasoning. The streamed form also returned `ok`.

## omp with aspen3 models: open issue

On the desktop, omp gets an empty reply from every Lemonade model. omp sends
the `research-tools` extension's tools even with `--no-tools`. Their JSON
schemas use `"pattern": "\\S"`. llama.cpp in Lemonade refuses to build a
grammar from them:

- The unanchored form fails with `Pattern must start with '^' and end with '$'`.
- `^[\s\S]*\S[\s\S]*$` and `^\s*\S(.|\s)*$` fail with `failed to parse grammar`.

mesh-llm passes the streamed error on as an empty `200`, and omp retries four
times and prints nothing.

`^(.|\n|\r)*[^ \t\n\r](.|\n|\r)*$` matches `\S` on ASCII whitespace, and
llama.cpp accepts it: the request answered through the mesh. The extension
source is the uncommitted `add-arxiv-laya-omp-tools` change in the main
onix-core checkout, so it is not changed here.

aspen3 briefly left the desktop mesh during these tests. Its Tailscale path
from the desktop is relayed through `mia`, and SSH to it timed out; aspen2
reached it directly. It rejoined within minutes.
