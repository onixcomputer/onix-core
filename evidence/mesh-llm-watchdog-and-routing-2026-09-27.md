# Mesh-LLM watchdog and model routing (2026-09-27)

## API listener watchdog (`7eea3d0a`)

**Why.** mesh-llm 0.72.2 on britton-desktop stopped listening on 127.0.0.1:9337
while its process kept running:
- the console on 3131 answered and reported 99 in-flight requests;
- `ss` showed no listener;
- systemd saw a healthy unit.

**What.** Each sidecar gets a `-api-watchdog` timer that checks the API port every
minute. After three refused checks in a row, it restarts the sidecar. It ignores
a sidecar that is inactive, or that started less than 300 s ago.

**Proof** (britton-desktop, generation 868). A temporary nftables rule rejected
127.0.0.1:9337 with a TCP reset:
- the watchdog logged `refused a connection (1/3)` and `(2/3)`;
- it restarted the sidecar 155 s after the block (PID 9600 to 482521);
- the block was removed, and the API listened again at 01:32:24.

aspen3 runs the same timer (`/nix/store/x9mq9cg8izlpqhphdgwxgbddc8miq2d3-…aspen3…`,
built from the uncommitted main tree, which differed from the running system only
by the watchdog units).

## Requests routed to the wrong model (`c72dccab`, tenstorrent.nix `4694f26`)

### Symptom

omp sessions on `mesh/Qwen3.8-27B` intermittently failed with
`404 model not found: Qwen3.8-27B`, and omp's model discovery sometimes found no
such model at startup.

### Mechanism

It was traced with a polling monitor on `/api/plugins/endpoints`, py-spy and the
mesh-llm source:

1. After a masked prefill, the Qwen batch worker reads the first-token logits
   with `ttnn.to_torch`, which waits for every queued replay.
2. TT-NN's `from_device` binding held the GIL during that wait (py-spy:
   `Tensor::cpu -> wait_for_outstanding_reads` from `masked_prefill_slot_logits`).
3. `/v1/models` on port 8000 therefore took up to 17.43 s during a 30K-token
   prefill (median 1.7 ms).
4. mesh-llm's 3 s health probe failed, marked the endpoint `degraded`, and
   emptied its model list until the next probe 15 s later. One such window was
   01:51:08–01:51:20.
5. A request arriving then fell back to mesh-llm's first local runtime, the
   Qwen3-0.6B activation model, which rejected the name with 404.

### Fixes

- **tenstorrent.nix `4694f26`.** Releases the GIL in `from_device`,
  `copy_host_to_device_tensor` and `copy_device_to_host_tensor`.
- **mesh-llm patch `mesh-llm-route-named-models-only.patch`.**
  - A request that names a model now gets `503 … retry later` instead of going
    to a different model.
  - An endpoint keeps its models through one missed probe.
  - The degraded-probe unit test checks this and runs in the package check (passed).

### After (britton-desktop generation 869)

- `/v1/models` during a 30K-token prefill: worst 0.02 s over 96 samples.
- Eight omp tool-using tasks (37–74 s each): no errors, no 404s, no discovery
  failures. The endpoint stayed `healthy` throughout.
- aspen3 runs the patched mesh-llm
  (`/nix/store/308ww8rp8sfb898qp7k69q9qyx0ba4n2-…aspen3…`).

## Sampling default

Greedy stays the default: see tenstorrent.nix `docs/qwen38-27b-adoption.md`.
- **Greedy.** Eight reasoning prompts with known answers, at the template's
  `xhigh` effort: 8/8 correct, none capped, none looping.
- **Temperature 0.6.** Also 8/8 correct, none capped, none looping, but decode
  ran at half the per-user speed (11.5 vs 21.8 tok/s).

## Refill coexistence

A new request can be prefilled into a free decode slot while the batched decode
trace stays resident, provided every decode input is restaged. The masked-trace
refill of a 2,521-token prompt took 1.49 s. Rows stayed token-equal to the
reference. See tenstorrent.nix `3696f21` and
`.cairn/changes/qwen38-continuous-slot-scheduler/evidence/refill-coexistence.md`.

## Still open

aspen2 has been unreachable since about 01:16 UTC. Tailscale shows it offline;
on the LAN, SSH resets before the banner although ping answers. It has neither
the watchdog nor the routing patch, and it keeps its old invite configuration.
