## Phase 1: Package and Module Support

- [x] [serial] Omit the Linux-only Collie plugin from the wrapped Herdr package on Darwin while preserving the Linux bundle. r[onix.britton-air.herdr.package]
- [x] [serial] Expose a nix-darwin Home Manager module from the profiles service without changing NixOS output. r[onix.britton-air.herdr.profile]

## Phase 2: britton-air Configuration

- [x] [serial] Install the wrapped Herdr core in system packages and herdr-app in the brittonr profile. r[onix.britton-air.herdr.install]
- [x] [serial] Assign the herdr profile to britton-air and gate the Collie activation to Linux. r[onix.britton-air.herdr.profile]
- [x] [serial] Run the herdr-iroh relay as a per-user LaunchAgent with the fleet peer, gateway, and herdr_bin. r[onix.britton-air.herdr.relay]

## Phase 3: Release and Deploy

- [x] [serial] Publish the onixpkgs changes, update the onix-core input, and evaluate the Darwin toplevel. r[onix.britton-air.herdr.install]
- [x] [serial] Build the toplevel on britton-air's store and activate it. r[onix.britton-air.herdr.install]

## Phase 4: Saved Machines and Verification

- [x] [serial] List the same three saved machines as aspen3 on britton-air and record reachability. r[onix.britton-air.herdr.machines]
- [x] [serial] Verify Herdr core, plugins, herdr-app, the config link, the launchd relay, and the saved-machine list on britton-air. r[onix.britton-air.herdr.verification]
