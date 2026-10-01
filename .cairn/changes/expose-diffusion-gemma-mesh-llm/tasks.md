## Phase 1: Discovery

- [x] [serial] Inspect the active sidecar, private mesh contract and existing model catalog. r[onix.diffusion-gemma.mesh]

## Phase 2: Integration

- [x] [serial] Replace only Aspen1's primary endpoint and backend dependency in the authoritative inventory. r[onix.diffusion-gemma.mesh] r[onix.diffusion-gemma.mesh-isolation]
- [x] [serial] Preserve the existing Spark provider declaratively and retire its superseded runtime mesh override. r[onix.diffusion-gemma.mesh-isolation]
- [x] [serial] Build and activate the selected persistent mesh unit without restarting the model or unrelated services. r[onix.diffusion-gemma.mesh-isolation]

## Phase 3: Verification

- [x] [serial] Verify remote model discovery and real non-streaming and streaming inference from the existing desktop peer. r[onix.diffusion-gemma.mesh]
- [x] [serial] Verify protected service identities, focused configuration validation and the completed native lifecycle. r[onix.diffusion-gemma.mesh-isolation]

## Phase 4: OMP discovery follow-up

- [x] [serial] Replace fixed OMP mesh entries with live discovery and a managed session refresh timer. r[onix.diffusion-gemma.mesh]
- [x] [serial] Correct authoritative catalog replacement by activating the pinned upstream OMP release with its supported compiler/runtime pairing. r[onix.diffusion-gemma.mesh]
- [x] [serial] Verify live desktop OMP discovery, cache bypass, model removal, outage fallback and recovery without changing the default model. r[onix.diffusion-gemma.mesh-isolation]
