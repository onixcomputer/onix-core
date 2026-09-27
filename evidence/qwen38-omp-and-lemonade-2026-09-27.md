# Qwen3.8 for omp, Lemonade errors and temp space (2026-09-26/27)

## Branch

`underclass-mesh-desktop` was pushed to `origin` for the first time: 55 commits,
all by brittonr. No plaintext secrets were found: the vars entries are
sops-encrypted `secret` files plus key-group symlinks. The later commits below
are pushed too. No pull request was opened.

## aspen3 Lemonade

### Temp space

- **Cause.** Prometheus shows aspen3's `/tmp` (61 GB tmpfs) went from 0.3 GB to
  57.8 GB between 2026-09-24 09:00 and 2026-09-25 00:00. The data was build and
  test trees, mostly `noble-m6/m7-*` and `molten-node-*`.
- **Effect.** Every model load failed with
  `LLVM ERROR: IO failure on output stream: No space left on device`, and left a
  `/tmp/comgr-<pid>-*` directory behind.
- **Why no age rule.** Nothing written in such a burst is older than a day, so an
  age rule would not have prevented it.
- **Fix.** `1fe2b8b7` sets `TMPDIR=/var/tmp` (disk) for `lemonade` and
  `lemonade-rpc-worker`, so ROCm's code-object compiler and the server log no
  longer depend on `/tmp`.

### Errors inside streams

- **Cause.** When llama-server rejects a streamed request, Lemonade 10.2.0 has
  already sent `200 text/event-stream`, and it forwards the bare JSON error. The
  example here was a tool schema with the unanchored pattern `"\S"`.
- **Effect.** mesh-llm correctly ignores that as malformed SSE. omp saw an empty
  reply and retried.
- **Fix.** `87513a99` patches Lemonade (`patches/lemonade-sse-error-event.patch`)
  to send such a body as one `data:` event.

### Deployment

- Built from the uncommitted main tree plus both changes:
  `/nix/store/wmh4dpv4261baw1j425xdxb0y8virybd-nixos-system-aspen3-26.11.20260924.34ca302`.
- Against the running system, only `lemonade.service` (TMPDIR) and the
  restart-trigger or unit-script hashes of units that reference the rebuilt
  Lemonade package changed.
- Activated. It exited with status 4 because `celld-site-storage-provision`
  failed: RustFS on port 39000 refuses connections. That unit was already
  failing.

### After

- Lemonade's own response now ends with `data: {"error":{"code":400,"message":"… Pattern must start with '^' and end with '$'"…}}`.
- Both mesh nodes forward that event.
- omp prints the error and saves the raw request instead of an empty reply.

## Qwen3.8-27B on britton-desktop

### What changed

tenstorrent.nix `main`:

| Commit | Change |
| --- | --- |
| `63eeb04` | Pooled KV cache: 4,096 blocks, 8 GiB per chip, rows up to 65,536 tokens. Generation cap 8,192. DRAM allocator totals logged at startup. |
| `283d545` | OpenAI tool calls, `reasoning_content`, thinking controls, `max_completion_tokens`, windowed detokenizer. |
| `0dc1ecb` | Documentation. |
| `bd16b85` | Context-limit error worded as OpenAI does, so omp compacts on it. |

onix-core: `045b5e31` and `770930d0` bump the pin and raise the desktop limits.
The accelerator-inventory check was updated with them.

### Hardware checks

Bounded candidate run on port 8010, with production stopped:

| Check | Result |
| --- | --- |
| Startup | Ready in 700 s; masked traces captured at 354 s. |
| DRAM | 21.6 GiB allocated, 9.2 GiB free per chip with the 8 GiB pool. |
| Needle recall at 6K / 16K / 32K / 60K | Recalled at every size. |
| TTFT at those sizes | 3.3 / 9.2 / 19.2 / 39.2 s. |
| Decode at those sizes | 23.2 / 22.7 / 22.0 / 21.1 tok/s. |
| One 30K row and three short rows in one group | Needle recalled; short outputs byte-equal to their solo runs. |
| Two 20K rows in one group | Each recalled its own code. |
| Greedy parity with the 2,048-token build | Matches over the recorded output. |
| Structured reads | Unchanged. |
| Masked-trace releases | None. |

Production generations 866 and 867, after readiness:

- **Service:** `device-dram` shows the same 9.2 GiB free.
- **Tool round trip:** direct and through mesh-llm, non-streaming and streaming.
  - `read_file({"path": "/etc/hostname"})` with `finish_reason` `tool_calls`.
  - After the tool result, the answer "The file `/etc/hostname` contains the
    value `britton-desktop`."

omp (`mesh/Qwen3.8-27B`, native tools, full default prompt):

| Task | Prompt tokens | Result | Wall time |
| --- | --- | --- | --- |
| Read `/etc/hostname` | 8,246 | One `read` call, correct answer. | 19 s |
| Count `docs/*.md` and name the largest | 8,267 then 11,033 | Parallel `glob` and `bash` calls. "21 files, largest `qwen38-27b-adoption.md`", which matches `ls`. | 63 s |

omp config on both machines: `contextWindow 65536`, `maxTokens 8192`,
`reasoning true`, `compat.qwenTemplateReasoningEffort true`, and no
`supportsTools: false`. Backups are `models.yml.bak-20260927`.

Generation 867 was ready in 700 s, again with 9.2 GiB free. A 60,108-token prompt
with `max_tokens` 8,192 gets, directly and through mesh-llm: `400 This model's
maximum context length is 65536 tokens. The prompt (60108 tokens) and generation
(8192 tokens) require 68300. Please reduce the length of the messages or
max_tokens.` The `/etc/hostname` omp task still answers, in 18 s.

## Open issues

- **One request at a time.**
  - Agent sessions on aspen3 now use Qwen3.8. Between 23:36 and 23:49, requests
    of 5,655, 22,231 and 24,477 prompt tokens generated 5,186, 3,082 and 8,192
    tokens (the last one hit the cap), and each held the device for 229–384 s.
  - The batch worker admits requests only when a group starts, so concurrent
    agents queue behind each other. An omp run from aspen3 waited more than
    800 s.
  - Continuous slot admission, the existing `qwen38-continuous-slot-scheduler`
    design, is the remedy.
- **Session over the limit.** One aspen3 session had grown to 142,553 tokens
  and got 400 on every turn. `bd16b85` makes that error trigger omp's
  compaction.
- **mesh-llm listener.** mesh-llm 0.72.2 on the desktop lost its 127.0.0.1:9337
  listener after a request without `model` hung for 300 s. The console on 3131
  stayed up and reported 99 in-flight requests. Restarting the sidecar restored
  the API. The cause was not found.
- **aspen2 unreachable.** aspen2 has been unreachable since about 01:16 UTC:
  Tailscale offline, and SSH on the LAN resets before the banner. Its last
  metrics were healthy (48 GiB memory available, no OOM), with
  `llamacpp-server-qwen38-flash-next-aspen2` still starting. It keeps its old
  invite configuration.
