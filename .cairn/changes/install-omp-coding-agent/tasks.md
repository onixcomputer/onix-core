## Phase 1: Scope and wiring

- [x] [serial] Add a machine-scoped `omp-agents` instance that reuses the `llm-agents` module and targets `britton-desktop` and `aspen3`. r[onix.llm_agents.omp.scope]
- [x] [serial] Confirm the agent resolves from the pinned `llm-agents` input with no new flake input or lock node. r[onix.llm_agents.omp.source]

## Phase 2: Verification

- [x] [serial] Add a focused check that accepts the agent on both selected machines and rejects it on an unselected machine and under a bogus name. r[onix.llm_agents.omp.verification.focused]
- [x] [serial] Build the configured agent package and pass its smoke test. r[onix.llm_agents.omp.verification.smoke]
- [x] [serial] Run service contract validation and the repository Cairn gates. r[onix.llm_agents.omp.verification]

## Phase 3: Deployment

- [ ] [serial] Deploy `britton-desktop` and `aspen3` from the branch they already run. r[onix.llm_agents.omp.deployment]
- [ ] [serial] Resolve the agent executable on both targets and record the evidence. r[onix.llm_agents.omp.deployment.path]
