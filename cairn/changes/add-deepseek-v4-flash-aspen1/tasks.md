# Tasks: add-deepseek-v4-flash-aspen1

- [x] [serial] Add `pkgs/llamacpp-rocm-dspark` pinned to commit `0b14b87d7c20cb753b94b96854dd7b45306fc696` with HIP `gfx1151` and the guide cmake flags; register it in `flake-outputs/tools.nix` and the `shared-nix.nix` overlay. r[onix.aspen1.deepseek.runtime]
- [x] [serial] Extend `modules/llamacpp-server` schema and module with `extraModelFiles`, `draftModelRepo`, `draftModelFile`, `draftModelRevision`, backend `rocm-dspark`, subdirectory-aware pulls, and `--model-draft` wiring including a missing-draft startup guard. r[onix.aspen1.deepseek.module]
- [x] [serial] Add inventory service `deepseek-v4-flash-aspen1` with the verified model, drafter, and launch flags on port 13305; repoint the aspen1 mesh-llm `backendUnit`; remove `lemonade-aspen1`. r[onix.aspen1.deepseek.serving] r[onix.aspen1.deepseek.exclusivity]
- [~] [serial] Run `cairn validate` plus proposal/design/tasks gates, build `llamacpp-rocm-dspark`, and evaluate `nixosConfigurations.aspen1` to confirm the unit wiring and Lemonade absence. r[onix.aspen1.deepseek.runtime] r[onix.aspen1.deepseek.serving] r[onix.aspen1.deepseek.exclusivity]
- [ ] [serial] Deploy to aspen1, wait for the ~115 GB model pull, and run the live probes: health check, `What is 2+2?` chat completion, DSpark speculative activity in server output, and a negative check that `lemonade.service` is absent. r[onix.aspen1.deepseek.validation]
- [ ] [serial] Sync accepted spec deltas, archive the change, and commit evidence. r[onix.aspen1.deepseek.validation]
