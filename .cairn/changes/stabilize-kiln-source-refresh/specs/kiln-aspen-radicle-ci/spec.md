# Kiln Aspen Radicle CI Specification Delta

## ADDED Requirements

### Requirement: Source refresh becomes quiescent

r[onix.radicle_ci.aspen_authority.refresh_quiescence] The source-admission shell MUST inspect required access and default ACL entries before mutation, MUST update only missing entries, and MUST leave an already admitted repository unchanged so the source-refresh path remains armed.

#### Scenario: Required ACL entries are current

r[onix.radicle_ci.aspen_authority.refresh_quiescence.scenario.current]
- GIVEN every admitted directory and file already has its required source-group ACL entries
- WHEN the source-refresh service runs
- THEN it MUST make no ACL mutation
- AND the source-refresh path MUST remain active without reaching its start limit

#### Scenario: A new object lacks source-group access

r[onix.radicle_ci.aspen_authority.refresh_quiescence.scenario.missing-entry]
- GIVEN a new admitted Git object or directory lacks one required source-group ACL entry
- WHEN the source-refresh service runs
- THEN it MUST add only the missing bounded entry
- AND a settling refresh MUST observe the current ACL and make no further mutation

#### Scenario: Admission would retrigger without a bound

r[onix.radicle_ci.aspen_authority.refresh_quiescence.scenario.self-trigger]
- GIVEN a proposed admission command rewrites current ACLs, widens source permissions, disables the path unit, or increases retry limits instead of removing the loop
- WHEN the Kiln Aspen module check runs
- THEN the proposal MUST fail
- AND the provider MUST retain its existing read-only source view and finite readiness bound
