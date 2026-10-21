## Phase 1: Discovery

- [x] [serial] Probe the live Underclass wire contract and the pinned Mesh-LLM endpoint, normalization and plugin identity paths. r[onix.underclass.mesh.gateway] r[onix.underclass.mesh.route]

## Phase 2: Implementation

- [x] [serial] Add the loopback translating gateway package with request, stream and HTTP behavior tests. r[onix.underclass.mesh.gateway]
- [x] [serial] Run the gateway from the Underclass module with a systemd credential, loopback-only hardening and a local-pool assertion. r[onix.underclass.mesh.gateway] r[onix.underclass.mesh.isolation]
- [x] [serial] Register the desktop's named `underclass` endpoint and make named openai-endpoint entries report their configured plugin name. r[onix.underclass.mesh.route]

## Phase 3: Verification

- [x] [serial] Build the packages, run the existing mesh and agent checks, and evaluate selected and unselected machines. r[onix.underclass.mesh.isolation]
- [x] [serial] Activate only the gateway and desktop sidecar, then verify discovery and real inference from Aspen2 through mesh transport while protected services keep their identities. r[onix.underclass.mesh.route] r[onix.underclass.mesh.isolation]
- [x] [serial] Record observed results, activation limits and rollback, and validate the native Cairn change. r[onix.underclass.mesh.gateway]

## Phase 4: Managed deployment

- [x] [serial] Derive a conversation affinity key when a client sends none, keeping each conversation on one pooled account. r[onix.underclass.mesh.gateway]
- [x] [serial] Carry the integration and its Underclass and research-forwarder prerequisites onto the desktop's deployed lineage, with a lock change limited to the new input and unit parity against the running overrides. r[onix.underclass.mesh.deployment]
- [x] [serial] Compare closures, dry-activate, activate the generation, retire every runtime and control override, and adopt the managed units. r[onix.underclass.mesh.deployment]
- [x] [serial] Verify managed ownership, the Underclass pool, research ingress and Aspen2 inference, including a sticky second turn. r[onix.underclass.mesh.deployment] r[onix.underclass.mesh.route]
