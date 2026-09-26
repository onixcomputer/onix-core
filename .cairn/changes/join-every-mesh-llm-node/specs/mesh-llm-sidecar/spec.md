# Mesh Llm Sidecar Specification Delta

## Purpose

Keep the private Mesh-LLM network connected across networks and while any single node is offline.

## ADDED Requirements

### Requirement: Joiners invite every other node

r[onix.mesh_llm.invites] Every joiner MUST hold one invite for each other node of its instance, and MUST NOT hold its own. It MUST order the other joiners by name before the seed. The seed MUST NOT hold invites.

#### Scenario: A joiner lists every peer

r[onix.mesh_llm.invites.order]
- GIVEN an instance with one seed and several joiners
- WHEN a joiner's service is evaluated
- THEN it loads one `invite-<peer>` credential for each other node, other joiners in name order and then the seed
- AND it passes each credential as its own `--join-file`, in the same order
- AND it loads no invite for itself

#### Scenario: The seed originates the mesh

r[onix.mesh_llm.invites.seed]
- GIVEN the seed's service is evaluated
- WHEN its launch arguments and credentials are inspected
- THEN it has no `--join-file` and loads no invite

#### Scenario: One node offline

r[onix.mesh_llm.invites.resilience]
- GIVEN any single node is offline, including the seed
- WHEN the remaining sidecars run
- THEN each remaining node lists every other remaining node as a peer
- AND a joiner off the LAN reaches the others over their Tailscale addresses

### Requirement: Invites come from one shared secret generator

r[onix.mesh_llm.invites.secret] Invites MUST come from one shared, prompted Clan vars secret per instance, with one file per node, loaded at runtime through `LoadCredential`. The retired per-joiner `join-token` generator MUST NOT be declared.

#### Scenario: Invite secrets stay out of the store

- GIVEN a joiner starts
- WHEN systemd resolves its credentials
- THEN each invite comes from the shared Clan generator
- AND no invite appears in generated Nix configuration text
