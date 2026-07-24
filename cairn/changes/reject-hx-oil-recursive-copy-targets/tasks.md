## Phase 1: Planner safety

- [ ] [serial] Add a pure normalized path-component ancestry predicate for bulk-copy items. r[onix.hx_oil.bulk_copy.ancestry]
- [ ] [serial] Resolve source and target roots at the filesystem shell boundary before ancestry evaluation. r[onix.hx_oil.bulk_copy.ancestry]
- [ ] [serial] Validate every planned directory copy before executing any bulk item. r[onix.hx_oil.bulk_copy.rejection_atomicity]
- [ ] [serial] Return a specific equal-or-descendant target diagnostic without creating output paths. r[onix.hx_oil.bulk_copy.rejection_atomicity]

## Phase 2: Validation

- [ ] [serial] Add positive planner and CLI tests for sibling and external directory copies. r[onix.hx_oil.bulk_copy.validation]
- [ ] [serial] Add negative tests for equal, descendant, mixed-plan, and symlink-resolved descendant targets. r[onix.hx_oil.bulk_copy.validation]
- [ ] [serial] Assert rejected mixed plans leave every destination absent. r[onix.hx_oil.bulk_copy.rejection_atomicity]
- [ ] [serial] Rebuild the hx-oil package and run Cairn validation and gates. r[onix.hx_oil.bulk_copy.validation]
