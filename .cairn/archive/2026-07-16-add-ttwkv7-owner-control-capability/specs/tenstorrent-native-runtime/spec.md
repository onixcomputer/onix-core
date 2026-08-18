# Tenstorrent Native Runtime Delta

## ADDED Requirements

### Requirement: ttWKV7 least-privilege owner control
r[onix.tenstorrent.native_runtime.ttwkv7.owner_control] The managed Blackhole host MUST provide an immutable non-interactive owner-control interface whose privileged capability is limited to starting and stopping the exact device-1 owner unit and inspecting open files for the exact device-1 path, without granting probe execution or broader root authority.

#### Scenario: Exact capabilities validate without service mutation
- GIVEN the activated owner-control wrapper and sudo policy
- WHEN the operator invokes validation mode
- THEN passwordless permission exists for the exact owner start, owner stop, and device ownership inspection commands
- AND validation does not stop or start the owner or access a Tenstorrent device

#### Scenario: Isolation fails closed
- GIVEN the exact owner is active before isolation
- WHEN the operator invokes isolation mode
- THEN the wrapper stops the owner once and proves it inactive
- AND any failed inactive-state or open-owner check attempts to restore the owner before returning nonzero

#### Scenario: Restoration targets only the prior owner
- GIVEN a reviewed caller must restore device 1 after its bounded operation
- WHEN the caller invokes restore mode from its exit trap
- THEN the wrapper starts only the exact device-1 owner unit
- AND it proves that unit active before returning success

#### Scenario: Broad privileged commands remain denied
- GIVEN the evaluated passwordless command set for the owner-control user
- WHEN machine validation inspects its command paths and arguments
- THEN no wildcard systemctl, restart, unrelated unit, arbitrary device, or all-command permission is present
- AND unsupported wrapper modes or extra arguments fail before sudo executes

#### Scenario: Owner control does not authorize a probe
- GIVEN validation or isolation succeeds
- WHEN no separate reviewed hardware authorization exists
- THEN the wrapper does not invoke ttWKV7, select a device, create runtime state, retry, or claim compatibility
- AND the operator does not execute a hardware probe
