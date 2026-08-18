# hx-oil Filesystem Safety Specification Delta

## Purpose

Reject bulk-copy plans that would recursively copy a directory into itself or one of its descendants.

## ADDED Requirements

### Requirement: Bulk-copy destinations preserve source ancestry safety

r[onix.hx_oil.bulk_copy.ancestry] `hx-oil` MUST reject a directory-copy plan when the normalized destination is equal to or nested beneath the normalized source directory.

#### Scenario: Sibling directory copy is accepted

r[onix.hx_oil.bulk_copy.ancestry.sibling]
- GIVEN a marked source directory and a target directory outside the source tree
- WHEN `hx-oil` builds the bulk-copy plan
- THEN planning succeeds
- AND the destination is the target joined with the source entry name

#### Scenario: Descendant target is rejected

r[onix.hx_oil.bulk_copy.ancestry.descendant]
- GIVEN a marked source directory and a target directory located beneath that source
- WHEN `hx-oil` builds the bulk-copy plan
- THEN planning MUST fail with an ancestry diagnostic
- AND no destination directory is created

#### Scenario: Symlink-resolved descendant is rejected

r[onix.hx_oil.bulk_copy.ancestry.symlink]
- GIVEN a textual target outside the source path resolves through a symlink to a directory beneath the source
- WHEN `hx-oil` resolves and validates the bulk-copy plan
- THEN planning MUST fail as a descendant target

### Requirement: Unsafe bulk-copy rejection is mutation-free

r[onix.hx_oil.bulk_copy.rejection_atomicity] `hx-oil` MUST validate every bulk-copy item's ancestry before executing any item in the plan.

#### Scenario: Mixed plan contains an unsafe item

r[onix.hx_oil.bulk_copy.rejection_atomicity.mixed]
- GIVEN a multi-item bulk-copy selection contains valid items and one descendant-target directory
- WHEN execution is requested
- THEN the complete plan is rejected before mutation
- AND none of the valid item destinations are created

### Requirement: Bulk-copy ancestry has positive and negative coverage

r[onix.hx_oil.bulk_copy.validation] The `hx-oil` test suite MUST cover valid external copies and invalid equal, descendant, and symlink-resolved descendant targets.

#### Scenario: Focused regression suite runs

r[onix.hx_oil.bulk_copy.validation.focused]
- GIVEN the bulk-copy planner and CLI implementation
- WHEN the focused Rust tests run
- THEN valid sibling and external copies pass
- AND every unsafe ancestry case fails with the expected diagnostic
