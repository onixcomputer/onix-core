# merge-when-green Push Safety Specification Delta

## Purpose

Prevent auto-merge preparation from overwriting unseen remote branch commits.

## ADDED Requirements

### Requirement: Default pushes are non-destructive

r[onix.merge_when_green.push.default_safe] `merge-when-green` MUST NOT issue a bare force push during its default workflow.

#### Scenario: New branch push

r[onix.merge_when_green.push.default_safe.new]
- GIVEN the selected remote branch does not exist
- WHEN the tool pushes prepared commits
- THEN it creates the branch with a normal push
- AND no force option is present

#### Scenario: Existing branch fast-forwards

r[onix.merge_when_green.push.default_safe.fast_forward]
- GIVEN the prepared local branch is a fast-forward of the observed remote branch
- WHEN the tool pushes
- THEN it uses a normal fast-forward push
- AND preserves every observed remote commit

### Requirement: Rewritten history requires an exact lease

r[onix.merge_when_green.push.lease] A rewritten-history push MUST require explicit operator intent and MUST use `--force-with-lease` bound to the exact previously observed remote branch object.

#### Scenario: Exact lease permits intended rewrite

r[onix.merge_when_green.push.lease.success]
- GIVEN the operator explicitly permits a lease-protected rewrite
- AND the remote branch still points to the observed object
- WHEN the tool pushes rebased history
- THEN the push uses an exact force-with-lease argument
- AND the update may proceed

#### Scenario: Concurrent remote update rejects rewrite

r[onix.merge_when_green.push.lease.stale]
- GIVEN the remote branch advances after the tool records its object
- WHEN the tool attempts the lease-protected push
- THEN the push MUST fail
- AND the remote-only commits remain intact

### Requirement: Push policy is tested without hosted side effects

r[onix.merge_when_green.push.validation] The repository MUST include positive and negative tests for push command construction and stale-lease behavior using an isolated local Git remote.

#### Scenario: Bare force is absent

r[onix.merge_when_green.push.validation.no_force]
- GIVEN every supported push mode
- WHEN command arguments are generated in tests
- THEN none contains bare `--force`
- AND rewritten mode contains the expected exact lease
