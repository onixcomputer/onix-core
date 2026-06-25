# aspen3-krea2-image-inference Specification

## Purpose

Define the safe path for running Krea 2 image generation on `aspen3` while preserving the existing Lemonade LLM and speech service.

## Requirements

### Requirement: Krea2-capable backend

r[onix.aspen3.krea2.backend] The system MUST run Krea 2 only through an image backend version that supports the Krea2 architecture.

#### Scenario: Reject incompatible backend

r[onix.aspen3.krea2.backend.reject_old_backend]
- GIVEN the deployed Lemonade `sd-cpp` backend pin does not support Krea2
- WHEN an operator evaluates Krea 2 enablement
- THEN the system does not register Krea 2 as an activation-time Lemonade model
- AND the operator is directed to use or package a Krea2-capable stable-diffusion.cpp backend first

#### Scenario: Accept compatible backend

r[onix.aspen3.krea2.backend.accept_supported_backend]
- GIVEN a stable-diffusion.cpp backend version that declares Krea2 support
- WHEN the operator configures Krea 2 execution
- THEN the system records the selected backend path or version as part of the Krea 2 configuration evidence

### Requirement: Explicit model assets

r[onix.aspen3.krea2.assets] The system MUST model Krea 2 image inference assets as explicit diffusion-model, text-encoder, and VAE inputs.

#### Scenario: Turbo assets are configured

r[onix.aspen3.krea2.assets.turbo]
- GIVEN Krea 2 Turbo is selected for inference
- WHEN the system renders the image backend configuration
- THEN the configuration includes a `main` Krea2 diffusion model
- AND the configuration includes a Qwen3-VL text encoder
- AND the configuration includes the required VAE

#### Scenario: Raw is not the default

r[onix.aspen3.krea2.assets.raw_not_default]
- GIVEN Krea 2 Raw is a base checkpoint intended mainly for finetuning or post-training
- WHEN the default `aspen3` image model set is rendered
- THEN Krea 2 Raw is not enabled by default
- AND Krea 2 Turbo remains the default Krea2 inference target

### Requirement: Direct smoke before service integration

r[onix.aspen3.krea2.smoke] The system MUST prove direct Krea 2 Turbo image generation before enabling a Lemonade-routed Krea 2 model.

#### Scenario: Direct smoke succeeds

r[onix.aspen3.krea2.smoke.success]
- GIVEN a Krea2-capable backend and complete Krea 2 Turbo assets on `aspen3`
- WHEN the operator runs the documented direct smoke command
- THEN the backend generates an image file
- AND the evidence records the command, backend, model variants, and output path

#### Scenario: Direct smoke blocks Lemonade registration

r[onix.aspen3.krea2.smoke.blocks_without_evidence]
- GIVEN no passing direct Krea 2 Turbo smoke evidence exists
- WHEN the Lemonade model inventory is evaluated
- THEN Krea 2 is not added to activation-time pulls
- AND existing Lemonade models remain configured as before

### Requirement: Lemonade service isolation

r[onix.aspen3.krea2.isolation] The system MUST preserve existing `aspen3` Lemonade LLM, Whisper, and service availability while Krea 2 support is introduced.

#### Scenario: Existing models remain available

r[onix.aspen3.krea2.isolation.existing_models]
- GIVEN `aspen3` already serves Qwen, VibeThinker, and Whisper through Lemonade
- WHEN Krea 2 support is added or tested
- THEN those existing model declarations remain present
- AND Krea 2 failures do not remove or rewrite their configuration

#### Scenario: Large pulls are opt-in

r[onix.aspen3.krea2.isolation.opt_in_pulls]
- GIVEN Krea 2 assets are large and backend compatibility is new
- WHEN the default machine activation runs before Krea 2 smoke evidence exists
- THEN Krea 2 assets are not pulled automatically
- AND unrelated Lemonade activation remains able to complete

### Requirement: Declarative Lemonade integration

r[onix.aspen3.krea2.lemonade] The system SHOULD expose Krea 2 through Lemonade only after the module can render `sd-cpp` multi-checkpoint models and image recipe options declaratively.

#### Scenario: Multi-checkpoint custom model renders

r[onix.aspen3.krea2.lemonade.multi_checkpoint]
- GIVEN a Krea 2 Turbo custom model declaration with `main`, `text_encoder`, and `vae` checkpoints
- WHEN the Lemonade module renders `user_models.json`
- THEN the rendered model uses the `sd-cpp` recipe
- AND the rendered model preserves all three checkpoint roles

#### Scenario: Image options avoid llama-only settings

r[onix.aspen3.krea2.lemonade.image_options]
- GIVEN a custom model uses the `sd-cpp` recipe
- WHEN the Lemonade module renders recipe options
- THEN image defaults and `sdcpp_args` are available
- AND llama.cpp-only context and cache arguments are not applied to the image model

### Requirement: Positive and negative verification

r[onix.aspen3.krea2.verification] The system MUST include positive and negative checks for the Krea 2 configuration path.

#### Scenario: Valid Krea2 configuration passes

r[onix.aspen3.krea2.verification.valid]
- GIVEN a Krea2-capable backend and all required Krea 2 Turbo asset roles
- WHEN the focused configuration checks run
- THEN the Krea 2 configuration is accepted

#### Scenario: Missing asset role fails

r[onix.aspen3.krea2.verification.missing_asset]
- GIVEN a Krea 2 model declaration missing the text encoder or VAE role
- WHEN the focused configuration checks run
- THEN the declaration fails closed with a clear diagnostic
