## Phase 1: Implementation

- [x] [serial] Pass one `--join-file` per invite and load one credential per invite, including through the DGX interface launcher. r[onix.mesh_llm.invites.order]
- [x] [serial] Derive each joiner's ordered peer list from the instance roles, and declare the shared invites generator on joiners only. r[onix.mesh_llm.invites.secret] r[onix.mesh_llm.invites.seed]
- [x] [serial] Move aspen2's mesh bind address to its live Tailscale address. r[onix.mesh_llm.invites.resilience]
- [x] [serial] Update the focused Mesh-LLM checks for invite order, the shared generator, the retired generator and the seed. r[onix.mesh_llm.invites.order] r[onix.mesh_llm.invites.secret]

## Phase 2: Secrets and deployment

- [ ] [serial] Enter each node's invite from its `/api/status`, and retire the per-joiner `join-token` vars. r[onix.mesh_llm.invites.secret]
- [ ] [serial] Build and check, compare closures, dry-activate, and activate britton-desktop and aspen3. r[onix.mesh_llm.invites.order]
- [ ] [serial] Verify one peer set across britton-desktop, aspen2 and aspen3, with `Qwen3.8-27B` listed on aspen3 while aspen1 is offline. r[onix.mesh_llm.invites.resilience]
