# Kiln Aspen Radicle Ci Status Sync Delta

## ADDED Requirements

### Requirement: Automatic CI status propagation after status writes

r[onix.radicle_ci.status_sync] Onix Core MUST propagate admitted CI status COB references to connected peers after each broker status write without operator action, by triggering one bounded repository sync when the bot namespace signed-refs file changes.

#### Scenario: Status write triggers a bounded sync

r[onix.radicle_ci.status_sync.bounded]
- GIVEN the broker has written a job COB update into the admitted repository storage
- WHEN the bot namespace signed-refs file changes
- THEN a status-sync oneshot SHALL run one bounded `rad sync` for the exact admitted repository as the `radicle` user
- AND the sync SHALL NOT dispatch, admit, or modify CI work

#### Scenario: Sync runs without host networking authority

r[onix.radicle_ci.status_sync.unix_only]
- GIVEN the status-sync oneshot runs
- WHEN it talks to the local Radicle node
- THEN the oneshot SHALL restrict address families to unix sockets
- AND it SHALL NOT open host network sockets directly, because the node owns all networking

#### Scenario: Sync failure stays visible

r[onix.radicle_ci.status_sync.visible]
- GIVEN the status-sync oneshot fails or exceeds its runtime bound
- WHEN the unit terminates
- THEN the failure SHALL remain visible as a failed systemd unit
- AND it SHALL NOT retry CI work, redispatch the broker, or restart any production runtime unit

#### Scenario: Sync is scoped to the admitted repository

r[onix.radicle_ci.status_sync.scoped]
- GIVEN the status-sync path and service units are installed
- WHEN they run
- THEN they SHALL reference only the exact admitted repository identifier and the bot namespace signed-refs path
- AND unrelated repositories, homes, credentials, and network sockets SHALL remain outside the unit's authority
