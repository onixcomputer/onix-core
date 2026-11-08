# Saved-machine Gateway Delta

## ADDED Requirements

### Requirement: Gateway ssh runs with the user's runtime directory
r[onix.herdr_gateway.runtime_dir] The herdr-iroh relay MUST run with `XDG_RUNTIME_DIR` set to its service user's `/run/user/<uid>` directory, so the ssh it starts for saved machines can expand that user's ssh config.

#### Scenario: A forwarded call reaches a saved machine
- **GIVEN** a saved SSH machine and an allowlisted peer
- **WHEN** the peer forwards a `ping` to that machine through the gateway
- **THEN** ssh MUST accept the user's config and the reply MUST come from the machine's Herdr server.
