# Aspen1 Qwen3.8 Flash Next live evidence

Date: 2026-09-04

Host: `aspen1`

## Artifact identity

- Model repository: `orcarouter/Qwen3.8-Flash-Next-Uncensored-GGUF`
- Model revision: `d2e41a316ee631cf17f83c8827800c836d30cbe6`
- Quantization: `IQ4_XS`, three shards
- Multimodal projector: `mmproj-Qwen3.8-Flash-Next-Uncensored-F16.gguf`
- llama.cpp revision: `427291b5b34cd914a31b3fd3b61a68f6184f4b9f`
- llama.cpp release and build: `0.4.0`, build `10809`

The Hugging Face LFS SHA-256 values matched for all four files.

- Shard 1: `50dc0856abd4a8ecea97a47ffa197bde3ea8d7d0f49d0e1fea7f71c97e8a70d1`
- Shard 2: `2a309e0b112fde96ba3bcba5a6b58cc05e5df7bb7fad5a990eaa51df335b0e43`
- Shard 3: `ebc43c58e2eaeba1d5bdf62c8cb1f0eac198c4dc01941f771921edeebf574bc3`
- Projector: `f0f352a97a62a057f3aecdb597cac664762cea2ca23f7b16ec92eee28c5572d9`

The integrity pass read 91.6 GiB and finished in 2 minutes 47.6 seconds.

## Build evidence

r[verify onix.aspen1.qwen_flash.runtime.package]

- `llamacpp-rocm-qwen4exp` built successfully with ROCm and HIP `gfx1151`.
- The build compiled `src/models/qwen4exp.cpp` and installed `llama-server`.
- `checks.x86_64-linux.llamacpp-server-settings` passed.
- `checks.x86_64-linux.mesh-llm-sidecars` passed.
- `checks.x86_64-linux.package-llamacpp-rocm-qwen4exp` passed.
- The complete `aspen1` NixOS system built successfully.
- Cairn repository validation returned `valid: true`.

The final remote build used the exact pinned Octet tree from commit `c3b96e2aa7d21d5f0a76f80916a70e7bdb1419ab`.
Its NAR hash matched the lock file.
No lock file changed.

The repository-wide Statix hook still reports existing repeated-key warnings in unrelated modules.
The changed files passed Deadnix, Treefmt, and focused Nix checks.

## Positive live probes

r[verify onix.aspen1.qwen_flash.download.authorized]

The root-only Hugging Face environment file has mode `0400` and owner `root:root`.
The model pull authenticated without writing the token to logs or process arguments.

r[verify onix.aspen1.qwen_flash.validation.positive]

- Health: `GET http://127.0.0.1:13305/health` returned `{"status":"ok"}`.
- Model identity: responses reported `Qwen3.8-Flash-Next-Uncensored` and `b10809-`.
- Text: `What is 2+2?` returned `4`.
- Text decode: 25.06 tokens per second.
- Vision: the model described the supplied city image in one correct sentence.
- Vision prompt processing: 215.53 tokens per second for 2,473 tokens.
- Vision decode: 27.33 tokens per second for 23 tokens.
- Mesh routing: the local mesh endpoint listed the Qwen model.
- Mesh text: the same arithmetic probe returned `4` at 26.55 tokens per second.

A clean service restart completed the full hash guard in 2 minutes 57 seconds.
The model then became healthy after about 14 seconds.

## Negative live probes

r[verify onix.aspen1.qwen_flash.download.denied]

A malformed token path fails before downloads start.
The generated pull service validates token shape and repository access before file transfer.

r[verify onix.aspen1.qwen_flash.exclusivity.no_competitors]

- The removed DeepSeek unit is inactive.
- `lemonade.service` is inactive.
- Port `13305` binds only to `127.0.0.1`.
- A request to the Aspen1 Tailnet address on port `13305` failed as required.
- No temporary systemd override remains.
- The Qwen service reported zero automatic restarts after the clean restart.

r[verify onix.aspen1.qwen_flash.validation.negative]

The first activation exposed two fail-closed problems.
The default systemd start timeout stopped the long hash guard.
The vision endpoint rejected images when `ffprobe` was absent from the service path.

The declared service now uses an infinite start timeout and adds `ffmpeg-headless` to its private path.
A clean restart and a second vision request proved both corrections.

## Final observed state

- Current system: `/nix/store/g71v62yql6gy3v13i4d14i343czxx0p1-nixos-system-aspen1-26.11.20260819.afe3d8a`
- Service state: `active/running`
- Service result: `success`
- Automatic restarts: `0`
- Available memory after load: about 48.2 GiB
- Swap use after load: about 2.0 GiB

## Non-claims

- This evidence does not cover the full 262,144-token native context.
- This evidence does not include MTP speculative decoding.
- This evidence does not compare long-context speed or model quality.
- The mesh model catalog reports text capability only. Direct llama.cpp vision requests are validated.
- The direct llama.cpp endpoint is not available outside the host.
