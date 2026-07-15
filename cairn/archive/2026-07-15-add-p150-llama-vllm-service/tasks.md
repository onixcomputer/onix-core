## Phase 1: Resource proof

- [x] [serial] Benchmark Supra on the CPU under isolated and synchronized VibeThinker load, requiring output parity and no throughput regression. r[onix.tenstorrent.concurrent_models.supra]
- [x] [serial] Inspect the pinned Tenstorrent image and source contract for exact entrypoint, model, port, device, cache, and credential behavior. r[onix.tenstorrent.vllm.p150_llama]

## Phase 2: Declarative services

- [x] [serial] Add a typed `tt-inference-server` module with a digest-pinned image, secret environment file, physical-device isolation, persistent cache, and positive/negative settings checks. r[onix.tenstorrent.vllm.p150_llama]
- [x] [serial] Move Supra declaratively to CPU, add the Llama-3.1-8B-Instruct service on card 1, and preserve VibeThinker unchanged on card 0. r[onix.tenstorrent.concurrent_models.supra] r[onix.tenstorrent.vllm.p150_llama]

## Phase 3: Verification

- [x] [serial] Run focused checks and the complete host build; deploy the non-secret configuration and populate the Hugging Face clan secret only from an authorized credential. r[onix.tenstorrent.vllm.p150_llama]
- [x] [serial] Validate all three endpoints concurrently, audit device ownership/journals/restarts, document the supported boundary, then sync and archive with evidence or the exact gated-token blocker. r[onix.tenstorrent.concurrent_models.supra] r[onix.tenstorrent.vllm.p150_llama]
