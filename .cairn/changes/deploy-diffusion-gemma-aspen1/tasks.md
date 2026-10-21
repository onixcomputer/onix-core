## Phase 1: Compatibility

- [x] [serial] Inspect both Aspen hosts and select the idle 128GB-class gfx1151 machine. r[onix.diffusion-gemma.runtime]
- [x] [serial] Prove the pinned ROCm runtime and structured-read implementation with actual execution. r[onix.diffusion-gemma.runtime]

## Phase 2: Deployment

- [x] [serial] Integrate an Aspen1-only persistent service and protect its exclusive GPU ownership without activating unrelated host changes. r[onix.diffusion-gemma.isolation]
- [x] [serial] Download the pinned original weights and run real text and seeded-canvas requests. r[onix.diffusion-gemma.runtime]

## Phase 3: Verification

- [x] [serial] Verify loopback binding, persistent service configuration, healthy restart and unchanged unrelated services; record measured evidence. r[onix.diffusion-gemma.isolation]
- [x] [serial] Validate the targeted configuration and native lifecycle artifacts, then remove temporary build/probe access. r[onix.diffusion-gemma.runtime] r[onix.diffusion-gemma.isolation]
