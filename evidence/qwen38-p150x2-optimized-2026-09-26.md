# Optimized Qwen3.8 on the britton-desktop P150x2 service

Date: 2026-09-26

## Change

`qwen38-p150x2.service` now runs the qwen38 package from tenstorrent.nix `main`:

- `923010c` adds the `POST /v1/systemone` structured-decision endpoint on top of
  `b155157`, which brought the fused GDN decode step, traced prefill, and
  streamed greedy decode on TT-Metal 0.77.
- `eba7a2c` keeps sampled batches within the sampled-fusion kernel's width.

The unit runs
`/nix/store/ngzwgsi2gyr5vcvc8zr20cbj529j2ng5-qwen38-0.1.0/bin/qwen38-p150x2-serve`
with these settings:

- `QWEN35_GDN_DECODE_FUSION=step`
- `QWEN35_GROUPED_PREFILL=1`
- `QWEN36_TRACED_PREFILL=1`
- `QWEN36_SAMPLED_FUSION=1`

The onix-core commits on `underclass-mesh-desktop`:

- `ee457bdf` adds the input `tenstorrent-nix-qwen`. The Qwen module and package
  come from it, and the machine check expects `qwen38-p150x2-serve`.
- `b069744d` turned sampled fusion off. This was an interim step; see
  generation 862.
- `20926833` pins `eba7a2c` and turns sampled fusion back on.

## Why the Qwen service has its own pin

`tenstorrent-nix` follows onix-core's nixpkgs. Moving it to `923010c` would:

- rebuild TT-Metal 0.77 and every Tenstorrent package from source;
- fail on `rwkv7-p150x2-evidence`, because hunks 3-5 of
  `fetch-queue-diagnostics.patch` no longer apply to TT-Metal 0.77's
  `system_memory_manager.cpp`.

`tenstorrent-nix-qwen` has no `follows`. The unit therefore runs the store path
built and measured in tenstorrent.nix. The other Tenstorrent packages stay on
`tenstorrent-nix` `51e07b8`, and no existing lock entry changed.

## Generations

- **861 (`ee457bdf`)**: startup trace preparation compiled the sampled route
  at every decode width.
  - At width 5 the fused `gated_delta_decode` kernel stopped with
    `TT_FATAL: num_heads exceeds the available compute grid`.
  - The kernel fits 4 users x 24 local value heads on 110 cores.
  - The service logged `masked-prefill-traces-failed` and prefilled eagerly.
- **862 (`b069744d`)**: with sampled fusion off, the traces captured. The
  service then rejected requests with a temperature above 0 (`only greedy
  temperature 0 is supported`).
- **863 (`20926833`)**: `eba7a2c` warms the sampled route only at widths 1-4
  and caps all-sampled batches at 4.
  - The traces captured (buckets 128, 256, 512 and 1024) in 455 s.
  - The service was ready 16 minutes after activation.

## Verification

- `britton-desktop-accelerator-inventory` and
  `britton-desktop-tenstorrent-driver` built for each candidate.
- Against generation 860, the closure replaces the `qwen36` package and its
  Python 3.14 closure with qwen38 and its tenstorrent.nix closure (+1.62 GiB).
- `dry-activate` listed the same `kiln-aspen-canary-lattice`, `polkit` and
  `dbus-broker` actions as earlier deployments, plus the Qwen restart.
- `switch-to-configuration` exited with status 4. The failed units were
  already failing before these changes: `celld`, `collie-serve` and
  `kiln-aspen-ci-host`.
- The `kache-nix` quota snippets failed as they did before.

## Runtime result on generation 863

| Test | Result |
|---|---|
| Greedy, one request | 23.5 decode tokens/s, TTFT 0.23 s (generation 860: 16.4 tokens/s, TTFT 1.41 s) |
| Sampled at temperature 0.7, one request | 12.3-12.7 decode tokens/s |
| Six concurrent sampled requests | one batch of 4 (11.5 tokens/s per user) and one of 2 (12.4) |
| Six concurrent greedy requests | one batch of 6, 22.0 tokens/s per user |
| Five sampled and one greedy request | one deterministic batch of 6 |
| `/v1/systemone`, 3-question ticket | 0.53-0.55 s in 2 device reads |
| `/v1/systemone`, 1-question read | 232 ms on route `masked-trace` |

- mesh-llm on `127.0.0.1:9337` serves `Qwen3.8-27B` from this service: TT-Metal
  0.77, 23.5 tokens/s.
- The journal has no `TT_FATAL`, trace release, or traceback since activation.
