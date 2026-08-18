# hx-oil Filesystem Safety Specification Delta

## Purpose

Treat an empty edited scope as an intentional final state so all delete flags produce an apply plan.

## ADDED Requirements

### Requirement: Every represented scope receives an apply plan

r[onix.hx_oil.apply.scope_planning] `hx-oil` MUST build an apply plan for every represented root or inserted-subdirectory scope, including a scope whose retained edited-entry list is empty.

#### Scenario: Sole root file is delete-flagged

r[onix.hx_oil.apply.scope_planning.sole_file]
- GIVEN a root scope snapshot contains one file
- AND the manifest marks that file for deletion
- WHEN dry-run or apply builds the scope plan
- THEN the plan contains a delete operation for that file
- AND the scope is not omitted as "No changes"

#### Scenario: Every file in an inserted subdirectory is delete-flagged

r[onix.hx_oil.apply.scope_planning.subdir]
- GIVEN an inserted-subdirectory scope contains entries
- AND every entry in that scope is delete-flagged
- WHEN the apply plan is built
- THEN the scope plan contains deletes for every original entry
- AND no duplicate deletion plan is produced

### Requirement: All-delete execution preserves directory safety

r[onix.hx_oil.apply.delete_safety] All-delete planning MUST retain stale-snapshot checks and MUST refuse deletion of a directory that is non-empty at validation time.

#### Scenario: Empty directory deletion succeeds

r[onix.hx_oil.apply.delete_safety.empty]
- GIVEN a snapshot contains an empty directory that is delete-flagged
- WHEN the plan is validated and applied without intervening changes
- THEN the directory is removed

#### Scenario: Non-empty directory deletion fails

r[onix.hx_oil.apply.delete_safety.non_empty]
- GIVEN a delete-flagged directory contains an unrepresented child
- WHEN the plan is validated
- THEN validation MUST fail before mutation
- AND the directory and child remain intact

### Requirement: Dry-run and apply agree for all-delete plans

r[onix.hx_oil.apply.delete_validation] The `hx-oil` tests MUST verify that dry-run output and apply output describe the same all-delete operations across positive and negative cases.

#### Scenario: Dry-run predicts sole-file deletion

r[onix.hx_oil.apply.delete_validation.parity]
- GIVEN a manifest whose only file is delete-flagged
- WHEN dry-run is followed by apply against the unchanged snapshot
- THEN both outputs contain the same delete operation
- AND the file is absent after apply
