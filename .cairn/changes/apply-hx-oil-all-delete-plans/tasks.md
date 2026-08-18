## Phase 1: Scope planning

- [ ] [serial] Inventory represented root and inserted-subdirectory scopes before filtering delete-flagged entries. r[onix.hx_oil.apply.scope_planning]
- [ ] [serial] Initialize empty retained-entry lists and pass them through the existing pure hunk planner. r[onix.hx_oil.apply.scope_planning]
- [ ] [serial] Prevent duplicate all-delete plans from the existing inserted-subdirectory fallback. r[onix.hx_oil.apply.scope_planning]
- [ ] [serial] Preserve stale-snapshot and non-empty-directory refusal before execution. r[onix.hx_oil.apply.delete_safety]

## Phase 2: Validation

- [ ] [serial] Add positive tests for sole-file, all-files, empty-directory, and inserted-subdirectory deletion. r[onix.hx_oil.apply.delete_validation]
- [ ] [serial] Add negative tests for non-empty directories, stale snapshots, and malformed empty scopes. r[onix.hx_oil.apply.delete_safety]
- [ ] [serial] Assert dry-run and apply render identical delete operations for an unchanged snapshot. r[onix.hx_oil.apply.delete_validation]
- [ ] [serial] Rebuild the hx-oil package and run Cairn validation and gates. r[onix.hx_oil.apply.delete_validation]
