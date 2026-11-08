## Phase 1: Configuration

- [x] [serial] Set `XDG_RUNTIME_DIR` on `herdr-iroh.service` from the service user's uid in the shared herdr-iroh tag. r[onix.herdr_gateway.runtime_dir]

## Phase 2: Release

- [ ] [serial] Rebuild britton-desktop and aspen3 from their recorded deployed source with only this change, review the closure, unit and `dry-activate` diffs, and switch. r[onix.herdr_gateway.runtime_dir]
- [ ] [serial] Verify each relay runs with the variable and its existing endpoint identity, and that forwarded calls to saved machines succeed. r[onix.herdr_gateway.runtime_dir]
