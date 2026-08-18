## Phase 1: Access policy

- [ ] [serial] Extend or clarify typed static-server bind and private-interface settings. r[onix.static_server.access.private]
- [ ] [serial] Remove global firewall exposure from private instances and render loopback or Tailscale-scoped access. r[onix.static_server.access.private]
- [ ] [serial] Preserve explicit wildcard/global exposure for public instances. r[onix.static_server.access.public]
- [ ] [serial] Evaluate deployed private and public static-server inventory after the policy change. r[onix.static_server.access.validation]

## Phase 2: Validation

- [ ] [serial] Replace the hand-written static-server fixture with production-module evaluation. r[onix.static_server.access.validation]
- [ ] [serial] Add positive reachability coverage for public and authorized private paths. r[onix.static_server.access.validation]
- [ ] [serial] Add a negative test proving a private backend port is unavailable from a non-Tailscale interface. r[onix.static_server.access.validation]
- [ ] [serial] Run focused module/VM checks plus Cairn validation and gates. r[onix.static_server.access.validation]
