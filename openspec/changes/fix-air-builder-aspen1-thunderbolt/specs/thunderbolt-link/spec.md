## MODIFIED Requirements

### Requirement: Thunderbolt link has bounded recovery for observed aspen1 failures

The system MUST recover or clearly alert when Thunderbolt host-to-host networking on a tagged machine enters an observed degraded state.

#### Scenario: Aspen1 retimer/host churn is detected

- GIVEN `aspen1` has `br-tbt` configured at `10.10.10.1/28`
- AND kernel logs contain repeated Thunderbolt `retimer disconnected`, `host disconnected`, or `failed to send properties changed notification` events
- WHEN the recovery service observes the failure burst
- THEN it MUST run a bounded recovery action for affected `thunderbolt-net` interfaces and the `br-tbt` bridge.
- AND it MUST rate-limit recovery to avoid an infinite bounce loop.

#### Scenario: Link health is checked after recovery

- GIVEN a recovery action completed on `aspen1`
- WHEN the health check runs
- THEN it MUST verify that `br-tbt` is routable with the configured static address.
- AND it SHOULD test peer reachability for configured Thunderbolt peers when those peers are expected online.
- AND it MUST emit a clear journal message when recovery did not restore health.

### Requirement: Thunderbolt network configuration remains deterministic

The system MUST keep Thunderbolt static addressing and NetworkManager ownership deterministic for all tagged hosts.

#### Scenario: Tagged host evaluates Thunderbolt config

- GIVEN a machine tagged with `thunderbolt-link`
- WHEN its NixOS configuration is evaluated
- THEN only machines with entries in the Thunderbolt address map receive `br-tbt` configuration.
- AND NetworkManager MUST leave `thunderbolt-net` interfaces unmanaged.
- AND the bridge MTU and member MTU MUST remain explicitly configured.
