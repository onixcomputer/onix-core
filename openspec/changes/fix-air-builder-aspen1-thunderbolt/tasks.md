## Phase 1: Builder truth model

- [ ] [serial] Add builder-target metadata for consumer-relative reachability or network class, covering `britton-air`, `aspen1`, and existing Linux clients.
- [ ] [depends:builder-metadata] Update `remote-builders.nix` to filter or reject builders based on the consuming machine and declared reachable path.
- [ ] [depends:builder-filter] Add an eval check proving `britton-desktop`/`aspen1` do not include unreachable `britton-air` unless the Mac route is explicitly allowed and live-validated.
- [ ] [depends:builder-filter] Preserve `britton-air` local `nix.linux-builder` behavior without advertising the nested VM as a remote Linux endpoint.

## Phase 2: Aspen1 Thunderbolt recovery

- [ ] [serial] Extend `thunderbolt-link.nix` recovery matching for observed retimer disconnect, host disconnect, and properties-changed notification failure bursts.
- [ ] [depends:thunderbolt-recovery] Add cooldown/rate-limit state and post-recovery health logging for `br-tbt`.
- [ ] [depends:thunderbolt-recovery] Keep deterministic bridge/member MTU, NetworkManager unmanaged ownership, and static address behavior intact.

## Phase 3: Validation and rollout

- [ ] [depends:builder-checks] Run `ncl export inventory/tags/builder-targets.ncl` or the repo-maintained Nickel validation path.
- [ ] [depends:builder-checks] Run Nix eval checks for `nixosConfigurations.{britton-desktop,aspen1,bonsai}.config.nix.buildMachines` with `--option allow-import-from-derivation true`.
- [ ] [depends:thunderbolt-recovery] Build/evaluate aspen1 NixOS config and inspect generated `thunderbolt-net-recovery` unit.
- [ ] [depends:live-access] Live-validate accepted builder SSH endpoints and aspen1 `br-tbt` health after deployment.
