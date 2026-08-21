# Package OpenBubbles Desktop Client

## Phase 1: Packaging

- [ ] [serial] Add `pkgs/openbubbles/default.nix` wrapping the pinned Linux release bundle for x86_64-linux. r[onix.openbubbles.package]
- [ ] [serial] Expose `openbubbles` as an x86_64-linux flake package in `flake-outputs/tools.nix`. r[onix.openbubbles.flake]

## Phase 2: Profile integration

- [ ] [serial] Replace `pkgs.bluebubbles` with the local `openbubbles` package in the shared social profile and update the brittonr social imports. r[onix.openbubbles.profile]

## Phase 3: Validation

- [ ] [serial] Build the `openbubbles` package and verify that every bundled ELF file resolves its required libraries. r[onix.openbubbles.package]
- [ ] [serial] Run treefmt, deadnix, and statix on the changed Nix files. r[onix.openbubbles.gates]
- [ ] [serial] Evaluate the `britton-desktop` home-manager profile and run Cairn validation plus gates. r[onix.openbubbles.gates]
