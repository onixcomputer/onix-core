## Context

`celld-lab` runs on three hosts and owns the `onix-celld-lab` RustFS bucket. Site needs a separate asset-only application because Celld stores one active deployment pointer per fleet bucket. Aspen1 is not currently reachable from this operator host. Aspen3 and britton-desktop are healthy Celld and RustFS peers.

The Clan Celld module is declared per instance, but its generated unit names, Unix identity, and provisioning state are fixed. This prevents safe composition of two instances on one machine.

## Decisions

### Decision: Keep one module and make its runtime resources instance-specific

**Choice:** Add a validated `runtimeName` setting. Use it for systemd service names, the Unix user and group, and the provisioning state directory. Keep the Clan credential generator keyed by the inventory instance name.

**Rationale:** The module already owns the complete Celld adapter boundary. A second module would duplicate storage policy, credentials, hardening, and deployment behavior. Explicit runtime names preserve the current lab names while making collisions visible in reviewed inventory.

### Decision: Use a two-node Site fleet

**Choice:** Run `celld-site` on aspen3 and britton-desktop. Use ports `32110` and `32111`, bucket `onix-site-celld`, and aspen3 as the only storage provisioner. Keep the ports below the default Linux ephemeral range.

**Rationale:** These are the two healthy requested hosts. Distinct ports, state directories, identities, credentials, and bucket authority isolate Site from the lab fleet. Aspen1 is excluded from Site rollout until it is reachable.

### Decision: Expose a standard AWS profile only to the publisher

**Choice:** Let a Celld instance declare an optional `publisherUser`. Generate a file with standard AWS environment variables from the same bucket-scoped secret and deploy it with mode `0400` to that user.

**Rationale:** Site already consumes the standard AWS credential chain. This keeps credentials out of Nickel, browser code, receipts, and the Site functional core. It also avoids changing the operator's default AWS files.

### Decision: Separate upload from activation evidence

**Choice:** Upload the static Site deployment once with explicit write authority. Restart each Celld Site unit after the upload. Probe the same asset through both node listeners.

**Rationale:** Celld 0.3.0 loads the active deployment at process start. An upload receipt proves storage mutation, not serving. Health and asset probes after restart provide bounded serving evidence.

## Risks / Trade-offs

- A two-node Celld fleet has less failure-domain coverage than the existing three-node lab fleet. This change makes no node-loss tolerance claim.
- The shared publisher credential permits writes only inside the Site fleet bucket. Compromise of the publisher user can still replace the Site application.
- The publisher must export the deployed variables for one command. The module does not replace ambient AWS configuration.
