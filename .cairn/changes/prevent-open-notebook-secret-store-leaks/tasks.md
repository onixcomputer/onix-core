## Phase 1: Secret boundary

- [ ] [serial] Split non-secret Open Notebook credential metadata from Clan-managed secret bootstrap input. r[onix.open_notebook.bootstrap.metadata]
- [ ] [serial] Reject inline `apiKey` and equivalent secret-bearing settings with a migration diagnostic. r[onix.open_notebook.bootstrap.secret_boundary]
- [ ] [serial] Assemble bootstrap credential payloads only from protected runtime secret files in the imperative shell. r[onix.open_notebook.bootstrap.secret_boundary]
- [ ] [serial] Document migration from inline credential values to the Clan secret input. r[onix.open_notebook.bootstrap.metadata]

## Phase 2: Validation

- [ ] [serial] Add a positive runtime test proving deployed secret consumption without store interpolation. r[onix.open_notebook.bootstrap.validation]
- [ ] [serial] Add negative module tests for inline secret fields and malformed secret payloads. r[onix.open_notebook.bootstrap.validation]
- [ ] [serial] Add a sentinel scan that fails if secret bytes appear in generated derivations or closures. r[onix.open_notebook.bootstrap.validation]
- [ ] [serial] Run focused Nix checks plus Cairn validation and proposal/design/tasks gates. r[onix.open_notebook.bootstrap.validation]
