## Phase 1: Relay Fix

- [x] [serial] Read Herdr's `agent.get` reply from `result.agent` in herdr-iroh, correct the test double to protocol 22 replies, and publish herdr-iroh `a342b855` after the corrected test failed on `1ee15bf8` and passed on the fix. r[onix.herdr_gateway.agent_info]

## Phase 2: Pin

- [x] [serial] Lock herdr-iroh to `a342b855dbd6483fe6407baba69d28ecdac71501` with a `flake.lock` delta limited to the herdr-iroh node. r[onix.herdr_gateway.pin]

## Phase 3: Release

- [ ] [serial] Rebuild britton-desktop from its recorded deployed source with only the herdr-iroh pin changed, review `diff-closures` and `dry-activate`, and switch only if Herdr itself is not restarted. r[onix.herdr_gateway.pin]
- [ ] [serial] Verify the relay runs the new executable with its existing endpoint identity, and that `relay.agent_session` reports `supported: true` for a live omp pane through the deployed binary. r[onix.herdr_gateway.agent_info]
- [ ] [serial] Confirm aspen3's running relay package equals the package built from the published pin. r[onix.herdr_gateway.pin]
