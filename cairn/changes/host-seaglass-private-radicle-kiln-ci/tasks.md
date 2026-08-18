## Phase 1: Private seed and acquisition

- [ ] [serial] Admit the Seaglass private RID to the desktop seed admission and seed it with scope `all`. r[onix.radicle_ci.seaglass_acquire]
- [ ] [serial] Enable the private seed HTTP Git endpoint on `britton-desktop` and prove `git ls-remote` resolves the exact reviewed Seaglass commit. r[onix.radicle_ci.seaglass_acquire]
- [ ] [serial] Add a negative fixture proving an undeclared repository is rejected by the private HTTP endpoint. r[onix.radicle_ci.seaglass_acquire]

## Phase 2: Flake inputs

- [ ] [serial] Add the `kiln` flake input from the public Radicle RID at a reviewed revision. r[onix.radicle_ci.seaglass_kiln]
- [ ] [serial] Add the `seaglass` flake input from the private seed at the reviewed revision. r[onix.radicle_ci.seaglass_acquire]

## Phase 3: Kiln and broker deployment

- [ ] [serial] Package and deploy the Kiln Radicle adapter and bind every accepted trigger to one Kiln run identity. r[onix.radicle_ci.seaglass_kiln]
- [ ] [serial] Deploy the Radicle CI broker with the Seaglass trigger filter and the Nix adapter executor. r[onix.radicle_ci.seaglass_execute]
- [ ] [serial] Add positive and negative adapter fixtures for malformed, unknown-version, and oversized triggers. r[onix.radicle_ci.seaglass_kiln]
- [ ] [serial] Bound executor memory, CPU, output, and timeout with systemd and record the bound in evidence. r[onix.radicle_ci.seaglass_execute]

## Phase 4: Seaglass check parity

- [ ] [serial] Enumerate the GitHub Actions rails that are not flake checks and record the gap list. r[onix.radicle_ci.seaglass_checks]
- [ ] [serial] Express the workspace nextest rail, generated-artifact gates, harness-matrix metadata, browser E2E default rail, and steel examples as Seaglass flake checks. r[onix.radicle_ci.seaglass_checks]
- [ ] [serial] Add a negative gap check proving GitHub-only rails are named when missing. r[onix.radicle_ci.seaglass_checks]

## Phase 5: Replication and cutover

- [ ] [serial] Replicate the private Seaglass repository to the secondary seed and record the observed seed set. r[onix.radicle_ci.seaglass_replication]
- [ ] [serial] Run an end-to-end push-to-status drill on `britton-desktop` and retain the exact-revision report. r[onix.radicle_ci.seaglass_execute]
- [ ] [serial] Retire GitHub Actions CI after parity evidence; keep the GitHub remote as a read-only mirror. r[onix.radicle_ci.seaglass_checks]
- [ ] [serial] Run Cairn validation and gates over this change package. r[onix.radicle_ci.seaglass_kiln]
