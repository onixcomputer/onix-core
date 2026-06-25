## Phase 1: Prove direct backend execution

- [ ] [serial] Select or package a Krea2-capable stable-diffusion.cpp backend for `aspen3`. r[onix.aspen3.krea2.backend]
- [ ] [serial] Declare the required Krea 2 Turbo model assets with explicit `main`, `text_encoder`, and `vae` roles. r[onix.aspen3.krea2.assets]
- [ ] [serial] Run a direct Krea 2 Turbo smoke generation on `aspen3` and record the command, backend version, model variants, and generated-output evidence. r[onix.aspen3.krea2.smoke] r[onix.aspen3.krea2.verification]
- [ ] [serial] Add a negative smoke check that fails closed when the selected backend does not report or support Krea2. r[onix.aspen3.krea2.backend] r[onix.aspen3.krea2.verification]

## Phase 2: Make Lemonade integration declarative

- [ ] [serial] Extend the Lemonade module schema to support multi-checkpoint `sd-cpp` custom models. r[onix.aspen3.krea2.lemonade]
- [ ] [serial] Extend Lemonade recipe options to support image defaults and `sdcpp_args` without applying llama.cpp-only settings to image models. r[onix.aspen3.krea2.lemonade] r[onix.aspen3.krea2.isolation]
- [ ] [serial] Add an `sd-cpp` backend binary override path for Krea2-capable backends. r[onix.aspen3.krea2.backend] r[onix.aspen3.krea2.lemonade]
- [ ] [serial] Register `user.Krea-2-Turbo` on `aspen3` only after direct smoke evidence passes. r[onix.aspen3.krea2.smoke] r[onix.aspen3.krea2.lemonade]

## Phase 3: Validate and deploy

- [ ] [serial] Run Nickel/Nix evaluation checks for the changed Lemonade inventory/module data. r[onix.aspen3.krea2.verification]
- [ ] [serial] Deploy to `aspen3` without disrupting existing Qwen, VibeThinker, and Whisper Lemonade models. r[onix.aspen3.krea2.isolation] r[onix.aspen3.krea2.verification]
- [ ] [serial] Verify the image API or direct backend path can generate an image after deploy. r[onix.aspen3.krea2.smoke] r[onix.aspen3.krea2.verification]
