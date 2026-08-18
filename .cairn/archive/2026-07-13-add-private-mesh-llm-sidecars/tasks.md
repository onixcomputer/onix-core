## Phase 1: Packaging and service implementation

- [x] [serial] Package Mesh-LLM v0.72.2 and openai-endpoint v0.1.2 with fixed hashes and NixOS ELF patching. r[onix.mesh_llm.validation]
- [x] [serial] Add the Mesh-LLM package to flake outputs and the shared machine overlay. r[onix.mesh_llm.validation]
- [x] [serial] Implement a schema-driven Clan sidecar module with explicit seed/joiner modes and local endpoint plugin configuration. r[onix.mesh_llm.sidecar]
- [x] [serial] Keep Mesh HTTP listeners loopback-only and expose only the selected private mesh UDP port. r[onix.mesh_llm.private.discovery] r[onix.mesh_llm.security.loopback]
- [x] [serial] Persist node identity under a hardened state directory owned by a dedicated unprivileged service user. r[onix.mesh_llm.private]
- [x] [serial] Supply the join token through a Clan-generated systemd credential and reject missing or placeholder values. r[onix.mesh_llm.security.credential] r[onix.mesh_llm.security.invalid_credential]

## Phase 2: Inventory and static validation

- [x] [serial] Register the module in Nix and Nickel module/schema registries. r[onix.mesh_llm.validation]
- [x] [serial] Assign Aspen1 as seed and `britton-desktop` as joiner with explicit Tailscale mesh addresses and local backend dependencies. r[onix.mesh_llm.sidecar] r[onix.mesh_llm.private]
- [x] [serial] Add positive checks for package contents, seed wiring, joiner credential wiring, and private listener policy. r[onix.mesh_llm.validation.focused]
- [x] [serial] Add negative checks for invalid credentials and absence on Aspen2 and Aspen3. r[onix.mesh_llm.security.invalid_credential] r[onix.mesh_llm.scope.excluded]
- [x] [serial] Run package, focused module, Nickel export, selected machine evaluation, and Cairn validation gates. r[onix.mesh_llm.validation]

## Phase 3: Private mesh rollout

- [x] [serial] Deploy Aspen1 first and verify its sidecar, local-only HTTP listeners, private discovery status, and local Lemonade models. r[onix.mesh_llm.sidecar.aspen1] r[onix.mesh_llm.private.discovery]
- [x] [serial] Capture Aspen1's runtime invite token into the Clan prompt secret without writing plaintext to tracked files. r[onix.mesh_llm.security.credential]
- [x] [serial] Deploy `britton-desktop` and verify VibeThinker is advertised through its local sidecar. r[onix.mesh_llm.sidecar.desktop]
- [x] [serial] Verify both nodes report the same mesh ID and mutual peer membership. r[onix.mesh_llm.private.membership]
- [x] [serial] Run chat-completion routing, backend withdrawal, and recovery probes through the local Mesh APIs. r[onix.mesh_llm.sidecar]
- [x] [serial] Confirm Aspen2 and Aspen3 were neither deployed nor assigned a Mesh-LLM unit. r[onix.mesh_llm.scope]
- [x] [serial] Record evidence, sync accepted specs, validate, and archive the completed Cairn change. r[onix.mesh_llm.validation]

## Verification Evidence

- Focused Nix check `checks.x86_64-linux.mesh-llm-sidecars` and Nickel inventory export passed in both the implementation tree and isolated rollout tree.
- Aspen1 bound HTTP only on `127.0.0.1:9337` and `127.0.0.1:3131`, QUIC only on `100.100.103.95:47916`, reported private publication, and preserved node ID `4787fe245d` across a clean systemd restart.
- `britton-desktop` bound HTTP only on loopback, QUIC only on `100.110.43.11:47916`, loaded its join token through an unprintable systemd credential, and preserved node ID `1332e00702` across restart.
- Both nodes reported mesh ID `0a09b454c02b7e59`, mutual direct peer membership, and the union of VibeThinker and Ornith models after restart.
- A VibeThinker completion routed from Aspen1 to the desktop and an Ornith completion routed from the desktop to Aspen1 without errors.
- Stopping Aspen1 Lemonade withdrew all Ornith models from the desktop Mesh API and returned `model_not_found`; restarting Lemonade restored the model inventory and a recovered Ornith request returned `4`.
- The focused negative checks prove the Mesh unit, credential generator, and UDP firewall rule remain absent from Aspen2 and Aspen3. Rollout commands targeted only Aspen1 and `britton-desktop`; direct SSH verification of the excluded hosts was unavailable from the active network path.
