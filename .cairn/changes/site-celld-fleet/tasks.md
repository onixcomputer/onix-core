## Phase 1: Multi-instance module

- [x] [serial] Add validated instance-specific Celld runtime resources for r[onix.site_celld_fleet.isolation].
- [x] [serial] Add optional publisher-profile generation and negative tests for r[onix.site_celld_fleet.credentials].

## Phase 2: Fleet composition

- [x] [serial] Compose the dedicated Site fleet on aspen3 and britton-desktop for r[onix.site_celld_fleet.composition].
- [x] [serial] Add generated topology checks for separate units, ports, buckets, provisioners, and credential ownership for r[onix.site_celld_fleet.validation].

## Phase 3: Rollout

- [ ] [serial] Validate and build the affected configurations for r[onix.site_celld_fleet.validation].
- [ ] [serial] Deploy aspen3, then britton-desktop, and verify unit and bucket authority for r[onix.site_celld_fleet.runtime].
- [ ] [serial] Upload the Site assets, restart both Site units, and probe the deployed asset through each listener for r[onix.site_celld_fleet.runtime].

## Phase 4: Completion

- [ ] [serial] Record bounded evidence and non-claims for r[onix.site_celld_fleet.runtime].
- [ ] [serial] Synchronize the accepted spec, archive the change, validate the final tree, and integrate the verified branch for r[onix.site_celld_fleet.validation].
