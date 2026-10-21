## Phase 1: Link policy

- [x] [serial] Replace `trustedInterfaces = [ "br-tbt" ]` with a peer address allow-list rendered from `tbAddresses`. r[onix.thunderbolt_link.access_control]
- [x] [serial] Drop link transit in both directions in a dedicated early nftables table. r[onix.thunderbolt_link.access_control.no_transit]
- [x] [parallel] Keep the static address, DHCP-off, link-local-off, and IPv6-RA-off settings, and pin the MTU to the largest usable frame size. r[onix.thunderbolt_link.mtu]
- [x] [parallel] Enforce the per-interface redirect and source-route sysctls from the guard. r[onix.thunderbolt_link.sysctls]

## Phase 2: Guard

- [x] [serial] Replace the log-scraping recovery service with a verify-then-repair guard. r[onix.thunderbolt_link.guard]
- [x] [serial] Trigger the guard from `TUNNEL_EVENT` udev events and from a periodic timer. r[onix.thunderbolt_link.guard.trigger]
- [x] [serial] Bound repairs with a cooldown, and never repair a link that has no carrier. r[onix.thunderbolt_link.guard.cooldown]
- [x] [serial] Run the guard against the live link on `aspen1` and `aspen2` and record the healthy, no-carrier, and repaired outcomes. r[onix.thunderbolt_link.validation.guard]

## Phase 3: Cluster selection

- [x] [serial] Select the cluster backend from the machine hardware inventory so a host without an RDMA controller uses the USB4 link. r[onix.thunderbolt_link.selection]
- [x] [serial] Confirm the rendered cluster env on `aspen1` and `aspen2` names `br-tbt` with the thunderbolt backend. r[onix.thunderbolt_link.validation.selection]

## Phase 4: Observability

- [x] [parallel] Alert on `br-tbt` MTU drift. r[onix.thunderbolt_link.observability]
- [x] [parallel] Confirm the guard's failure state is reported by the existing failed-service alert. r[onix.thunderbolt_link.observability.guard]

## Phase 5: Verification

- [x] [serial] Evaluate both machine configurations and build both top-level closures. r[onix.thunderbolt_link.validation.evaluation]
- [x] [serial] Deploy to `aspen1` and `aspen2` and confirm the link state, the MTU, the address, and the nftables counters. r[onix.thunderbolt_link.validation.access_positive]
- [x] [serial] Prove the firewall with a peer-source connection (accepted) and a non-peer source in the same subnet (dropped with counter evidence). r[onix.thunderbolt_link.validation.access_positive]
- [x] [serial] Prove no transit with a routed attempt from the link to a tailnet address (dropped with counter evidence). r[onix.thunderbolt_link.validation.access_negative]
- [x] [serial] Re-measure throughput and round-trip time after the change and confirm no regression against the recorded baseline. r[onix.thunderbolt_link.validation.performance]
