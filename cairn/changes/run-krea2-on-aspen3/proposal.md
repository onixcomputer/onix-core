## Why

`aspen3` should be able to run Krea 2 image generation locally, but adding `krea/Krea-2-Raw` or `krea/Krea-2-Turbo` directly to the existing Lemonade model list is unsafe today. Those Hugging Face repos are Diffusers `Krea2Pipeline` models, while the deployed Lemonade package serves images through `sd-cpp` backed by an older stable-diffusion.cpp pin that does not declare Krea2 support.

We need a narrow, evidence-first path: prove Krea 2 Turbo with a Krea2-capable image backend on `aspen3`, then make a declarative Lemonade integration only after the direct backend smoke test passes.

## What Changes

- Add a Krea 2 Turbo path for `aspen3` using a Krea2-capable stable-diffusion.cpp backend.
- Prefer direct backend smoke testing before any Lemonade registration or activation-time model pulls.
- Model the required multi-file image assets explicitly: Krea2 diffusion model, Qwen3-VL text encoder, and VAE.
- Keep Krea 2 Raw out of default inference paths because the model card describes it as a base checkpoint for finetuning/post-training rather than recommended inference use.
- Prepare the Lemonade module for a later declarative integration by supporting `sd-cpp` multi-checkpoint custom models and an overrideable `sd-cpp` backend binary.

## Impact

- **Scope**: `aspen3` local image generation and optional Lemonade image-model registration.
- **Risk**: Large model downloads, fast-moving Krea2 backend support, and possible ROCm runtime incompatibility on Strix Halo.
- **Non-goals**: Do not replace the existing Lemonade LLM/Whisper service; do not auto-pull Krea2 by default before smoke evidence exists; do not make Raw the default model.
- **Testing**: Validate Cairn gates, run a direct Krea 2 Turbo smoke generation on `aspen3`, and add positive/negative configuration checks before enabling Lemonade registration.
