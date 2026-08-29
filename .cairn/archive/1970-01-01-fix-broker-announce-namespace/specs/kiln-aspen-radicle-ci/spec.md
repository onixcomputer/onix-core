# Kiln Aspen Radicle Ci Broker Announce Delta

## ADDED Requirements

### Requirement: Broker announce declares its node namespace

r[onix.radicle_ci.broker_announce_namespace] Onix Core MUST build the production CI broker so that its job COB announcements declare the broker's own node namespace instead of an empty namespace list.

#### Scenario: Announce carries the bot namespace

r[onix.radicle_ci.broker_announce_namespace.namespace]
- GIVEN the patched broker announces a job COB change
- WHEN the Radicle node processes the announcement
- THEN the announced namespace SHALL be the broker's own node id
- AND the node SHALL NOT reject the announcement with an empty refs error

#### Scenario: Patch is pinned in the machine evaluation

r[onix.radicle_ci.broker_announce_namespace.pinned]
- GIVEN the machine configuration is evaluated
- WHEN the broker package is built
- THEN the announce namespace patch SHALL be present in the package patch set
- AND the machine checks SHALL fail if the patch is removed
