# Tasks

## Phase 1: Packaging

- [ ] [serial] Package `@zvec/zvec-grep` v0.2.1 at revision `309a66995809243d3274fa8b5bea63ab11dda1a0` with Node 22 in Onix dev tooling. r[onix.zvec_grep.packaging]
- [ ] [serial] Record the reference revision, version, project, and Apache-2.0 license in repository references. r[onix.zvec_grep.reference]
- [ ] [serial] Verify the packaged tool runs offline from a dev shell. r[onix.zvec_grep.packaging] r[onix.zvec_grep.verification]

## Phase 2: Configuration and exact path

- [ ] [serial] Add typed Nickel configuration for workspace roots, exclusions, model selection, and embedding mode. r[onix.zvec_grep.config]
- [ ] [serial] Add configuration validation with positive admission and malformed-configuration denial. r[onix.zvec_grep.config] r[onix.zvec_grep.verification]
- [ ] [serial] Confirm exact `--rg` queries work without an index or model. r[onix.zvec_grep.exact] r[onix.zvec_grep.verification]

## Phase 3: Agent access and privacy

- [ ] [serial] Wire the loopback MCP endpoint with bearer authentication where supported. r[onix.zvec_grep.agent]
- [ ] [serial] Assert loopback binding and bearer denial. r[onix.zvec_grep.agent] r[onix.zvec_grep.verification]
- [ ] [serial] Verify remote embedding is denied without an explicit workspace grant. r[onix.zvec_grep.privacy] r[onix.zvec_grep.verification]
- [ ] [serial] Run the focused rail plus Cairn validation and gates. r[onix.zvec_grep.verification]
