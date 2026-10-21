# Thunderbolt Link Specification

## Purpose

Define the behaviour of the direct USB4/Thunderbolt host-to-host link: its addressing, its frame size, who may reach services over it, how it is repaired, and when the cluster uses it as its transport.

## Requirements

### Requirement: Static link addressing

r[onix.thunderbolt_link.addressing] The system MUST assign the USB4 link address of a host from the static address map and MUST fail closed for a host that has no mapping.

#### Scenario: Mapped host receives the link address

r[onix.thunderbolt_link.addressing.mapped]
- GIVEN a machine is tagged `thunderbolt-link` and is listed in the address map
- WHEN its NixOS configuration is evaluated
- THEN the bridge carries that host's static address on the configured subnet
- AND address autoconfiguration, link-local addressing, and IPv6 router advertisements are disabled

#### Scenario: Unmapped host fails closed

r[onix.thunderbolt_link.addressing.unmapped]
- GIVEN a machine is tagged `thunderbolt-link` but has no address mapping
- WHEN its NixOS configuration is evaluated
- THEN evaluation fails with a diagnostic naming the missing address map entry

### Requirement: Pinned frame size

r[onix.thunderbolt_link.mtu] The system MUST pin the link MTU to the largest frame size the driver accepts, and MUST restore it when it drifts.

#### Scenario: MTU is the maximum usable frame size

r[onix.thunderbolt_link.mtu.pinned]
- GIVEN a host carries the link address
- WHEN the link interfaces come up
- THEN the bridge and its members use the pinned MTU
- AND the pinned value is two bytes below the driver maximum reported by the member interface

#### Scenario: Drifted MTU is restored

r[onix.thunderbolt_link.mtu.restored]
- GIVEN the link interface reports an MTU other than the pinned value
- WHEN the guard verifies the link
- THEN the guard restores the pinned MTU on the member before the bridge
- AND the host reports the drift to the journal

### Requirement: Link access control

r[onix.thunderbolt_link.access_control] The system MUST admit link traffic only from the configured peers of the host, and MUST NOT forward any packet between the link and another interface.

#### Scenario: Configured peer reaches local services

r[onix.thunderbolt_link.access_control.peer]
- GIVEN a configured peer sends a packet to the host over the link
- WHEN the packet arrives
- THEN the link filter accepts it before the general firewall rules

#### Scenario: Unknown source is refused

r[onix.thunderbolt_link.access_control.unknown]
- GIVEN a source address that is not a configured peer of the host sends a packet over the link
- WHEN the packet arrives
- THEN the link filter drops it before any service can answer
- AND the drop counter increases

#### Scenario: The link is never a transit network

r[onix.thunderbolt_link.access_control.no_transit]
- GIVEN a forwarded packet enters or leaves through the link
- WHEN the packet reaches the forward hook
- THEN the link filter drops it
- AND the forward counter increases

#### Scenario: Link interfaces do not accept redirects

r[onix.thunderbolt_link.sysctls]
- GIVEN the link interfaces exist
- WHEN the guard runs
- THEN IPv4 redirect acceptance, redirect emission, and source routing are disabled on each link interface

### Requirement: Link guard

r[onix.thunderbolt_link.guard] The system MUST verify the link on kernel tunnel events and on a timer, and MUST repair a link that carries traffic badly with a bounded, rate-limited link cycle.

#### Scenario: Healthy link is verified without repair

r[onix.thunderbolt_link.guard.healthy]
- GIVEN the link has carrier, the configured address, the pinned MTU, and an answering peer
- WHEN the guard runs
- THEN the guard reports the link as healthy
- AND the guard leaves the link untouched

#### Scenario: Broken link is repaired

r[onix.thunderbolt_link.guard.repair]
- GIVEN the link has carrier but fails the address, MTU, or peer reachability check
- WHEN the guard runs and no repair is inside the cooldown window
- THEN the guard cycles the link members, re-applies the link parameters, and re-verifies
- AND a successful repair is reported to the journal

#### Scenario: Repair is rate limited

r[onix.thunderbolt_link.guard.cooldown]
- GIVEN the guard repaired the link inside the cooldown window
- WHEN the guard runs again while the link is still unhealthy
- THEN the guard reports the suppression and does not cycle the link

#### Scenario: Missing carrier is not repaired

r[onix.thunderbolt_link.guard.no_carrier]
- GIVEN the link reports no carrier
- WHEN the guard runs
- THEN the guard reports that no host-side repair is possible and does not cycle the link

#### Scenario: Kernel tunnel events trigger verification

r[onix.thunderbolt_link.guard.trigger]
- GIVEN the kernel reports a TUNNEL_EVENT for the USB4 domain
- WHEN the event is activated, deactivated, low bandwidth, or insufficient bandwidth
- THEN the guard is scheduled to verify the link
- AND a periodic timer also verifies the link regardless of events

### Requirement: Cluster transport selection

r[onix.thunderbolt_link.selection] The system MUST select the cluster backend from the machine hardware inventory, so that a host without an RDMA-capable controller uses the USB4 link.

#### Scenario: Host without RDMA hardware uses the link

r[onix.thunderbolt_link.selection.no_rdma_hardware]
- GIVEN a host carries the RDMA network tag and the cluster network tag
- AND its hardware inventory lists no RDMA-capable network controller
- WHEN its NixOS configuration is evaluated
- THEN the rendered cluster env selects the thunderbolt backend on the link interface
- AND evaluation emits a warning that the RDMA tag has no backing hardware

#### Scenario: Host with RDMA hardware keeps the RDMA backend

r[onix.thunderbolt_link.selection.rdma_hardware]
- GIVEN a host carries the RDMA network tag and the cluster network tag
- AND its hardware inventory lists an RDMA-capable network controller
- WHEN its NixOS configuration is evaluated
- THEN the rendered cluster env selects the RDMA backend

### Requirement: Link observability

r[onix.thunderbolt_link.observability] The system MUST report link health through the existing monitoring stack.

#### Scenario: MTU drift is alerted

r[onix.thunderbolt_link.observability.mtu]
- GIVEN the link bridge is scraped by the node exporter
- WHEN its MTU differs from the pinned frame size for the alerting window
- THEN an alert reports the changed MTU for that instance

#### Scenario: Guard failure is alerted

r[onix.thunderbolt_link.observability.guard]
- GIVEN the guard cannot restore a link that has carrier
- WHEN the guard exits with a failure status
- THEN the existing failed-service alert reports the unit

### Requirement: Validation evidence

r[onix.thunderbolt_link.validation] The system MUST include positive and negative validation evidence for access control, the guard, selection, and performance.

#### Scenario: Configuration and closures build

r[onix.thunderbolt_link.validation.evaluation]
- GIVEN both cluster hosts carry the link tag
- WHEN their configurations are evaluated and their top-level closures are built
- THEN evaluation succeeds and the nftables table, the guard, and the cluster env render as specified

#### Scenario: Guard behaviour is proven on the live link

r[onix.thunderbolt_link.validation.guard]
- GIVEN the change is deployed to both hosts
- WHEN the guard runs against a healthy link, against a link without carrier, and against a link whose peer tunnel was torn down
- THEN the healthy run reports no repair, the carrierless run reports that no host-side repair is possible, and the torn-down link is verified or repaired and reported

#### Scenario: Selection is proven for both cluster hosts

r[onix.thunderbolt_link.validation.selection]
- GIVEN both cluster hosts carry the link tag and the cluster network tag
- WHEN their rendered cluster env is read
- THEN each names the thunderbolt backend on the link interface

#### Scenario: Access control is proven on the live link

r[onix.thunderbolt_link.validation.access_positive]
- GIVEN the change is deployed to both hosts
- WHEN a configured peer connects to a service on the other host over the link
- THEN the connection succeeds

#### Scenario: Foreign sources and transit are refused on the live link

r[onix.thunderbolt_link.validation.access_negative]
- GIVEN the change is deployed to both hosts
- WHEN a non-peer address in the link subnet connects to a service, and when a packet is routed from the link toward a tailnet address
- THEN both are dropped and the corresponding filter counters increase

#### Scenario: Performance does not regress

r[onix.thunderbolt_link.validation.performance]
- GIVEN a throughput and latency baseline was measured before the change
- WHEN throughput and round-trip time are measured after the change
- THEN throughput stays within measurement noise of the baseline
- AND the round-trip time stays within its recorded range
