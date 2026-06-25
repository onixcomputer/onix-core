## Context

Krea 2 is a 12B text-to-image diffusion transformer. The upstream model cards expose Diffusers `Krea2Pipeline` checkpoints, and upstream stable-diffusion.cpp added Krea2 support after the `sd-cpp` version currently pinned by Lemonade 10.2.0. The deployed `aspen3` Lemonade service is already serving LLM and Whisper models; Krea2 work must not destabilize that path.

The safer route is to first run Krea 2 Turbo with a known Krea2-capable stable-diffusion.cpp binary and explicit model files, then integrate with Lemonade once backend compatibility and model asset layout are proven.

## Decisions

### 1. Smoke stable-diffusion.cpp before Lemonade

**Choice:** Build or select a Krea2-capable `sd-cli`/`sd-server` and run Krea 2 Turbo directly on `aspen3` before declaring a Lemonade model.

**Rationale:** Lemonade currently downloads/uses an older `sd-cpp` backend pin. A direct backend smoke test isolates Krea2 backend compatibility from Lemonade routing, registry, and activation-time pull behavior.

### 2. Default to Turbo, not Raw

**Choice:** Make Krea 2 Turbo the default inference target. Treat Krea 2 Raw as an explicit opt-in asset for finetuning or post-training experiments.

**Rationale:** Krea's Raw card says Raw is not recommended for inference. Turbo is the post-trained/distilled release intended for normal image generation.

### 3. Represent Krea2 as a multi-checkpoint image model

**Choice:** Track model assets as three explicit roles:

- `main`: Krea2 diffusion model, preferably GGUF for stable-diffusion.cpp.
- `text_encoder`: Qwen3-VL 4B text encoder.
- `vae`: VAE required by the backend.

**Rationale:** Lemonade already supports multi-checkpoint `sd-cpp` models in its built-in registry shape. The `onix-core` Lemonade module should expose that shape instead of squeezing Krea2 into a single LLM-style checkpoint.

### 4. Keep activation safe

**Choice:** Do not add Krea2 to activation-time `models` until a direct smoke test passes and the operator explicitly enables the model.

**Rationale:** Krea2 assets are large and backend support is new. Failed activation pulls should not block unrelated LLM service operation.

## Implementation Sketch

1. Package or fetch a Krea2-capable stable-diffusion.cpp build for `aspen3`.
2. Download or declare Krea 2 Turbo GGUF, Qwen3-VL text encoder, and VAE assets.
3. Run a direct `sd-cli` smoke generation using conservative settings.
4. Extend `modules/lemonade` schema/rendering to support `customModels.<name>.checkpoints`, `imageDefaults`, and `recipeOptions` for `sd-cpp` models.
5. Add an optional `sd-cpp` backend binary override in the Lemonade config/environment.
6. Register `user.Krea-2-Turbo` only after direct smoke evidence exists.

## Risks / Trade-offs

- A Krea2-capable stable-diffusion.cpp release may be newer than Lemonade's tested backend contract.
- ROCm builds may lag upstream CPU/Vulkan support.
- GGUF Krea2 repos are community-published and may not match the original Krea community license terms exactly.
- Full-quality Krea2 settings can be expensive; smoke tests should use bounded resolution/steps first.
