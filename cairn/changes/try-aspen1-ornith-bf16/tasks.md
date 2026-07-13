## Phase 1: Inventory

- [ ] [serial] Register the official Ornith 1.0 35B BF16 GGUF in the Aspen1 Lemonade custom model map. r[onix.aspen1.ornith.bf16]
- [ ] [serial] Add BF16 to Aspen1's pull list while retaining Q4_K_M and excluding Q8_0. r[onix.aspen1.ornith.bf16.inventory]

## Phase 2: Validation and deployment

- [ ] [serial] Run Nickel export plus Cairn validation and proposal/design/tasks gates. r[onix.aspen1.ornith.bf16.validation]
- [ ] [serial] Evaluate and deploy the focused Aspen1 system configuration. r[onix.aspen1.ornith.bf16.validation]
- [ ] [serial] Confirm BF16 is downloaded and run the positive non-thinking live inference probe. r[onix.aspen1.ornith.bf16.validation.positive]
- [ ] [serial] Inspect service and memory health, then verify Q4 remains a working fallback or roll back BF16 after failure. r[onix.aspen1.ornith.bf16.validation.negative]
- [ ] [serial] Sync the accepted requirement and archive the completed change with validation evidence. r[onix.aspen1.ornith.bf16.validation]
