## Phase 1: Runtime and model repair

- [x] [serial] Upgrade the ROCm/RPC llama.cpp package to a recent upstream tag. r[onix.aspen3.ornith.runtime]
- [x] [serial] Preserve the `llama-rpc-server` alias across the upstream RPC binary rename. r[onix.aspen3.ornith.runtime]
- [x] [serial] Replace `aspen3`'s served 35B Ornith Q8 model with the live-validated 35B Q4_K_M model. r[onix.aspen3.ornith.model]

## Phase 2: Validate

- [x] [serial] Build the upgraded llama.cpp package. r[onix.aspen3.ornith.verification]
- [x] [serial] Build and deploy the focused `aspen3` system configuration. r[onix.aspen3.ornith.verification]
- [x] [serial] Run positive live inference for `user.Ornith-1.0-35B-Q4_K_M`. r[onix.aspen3.ornith.verification]
- [x] [serial] Record the negative Q8 slash-loop diagnosis so Q8 is not treated as healthy. r[onix.aspen3.ornith.verification]
- [x] [serial] Run Cairn validation and gates for this change. r[onix.aspen3.ornith.verification]
