## Phase 1: Implementation

- [x] [serial] Add the `onixpkgs` input, following onix-core's `nixpkgs`, `llm-agents`, `wrappers`, and `treefmt-nix`, and drop the `horizon` input that onixpkgs now owns. r[onix.packages.onixpkgs]
- [x] [serial] Apply the onixpkgs overlay in `shared-nix.nix`, `modules/dgx-machine`, and `flake-outputs/checks.nix`, and replace the seven `self.packages` injections. r[onix.packages.onixpkgs]
- [x] [serial] Point every module, profile, machine, check, and dev-shell reference to a migrated package at `pkgs.<name>` or `inputs'.onixpkgs.<name>`. r[onix.packages.onixpkgs]
- [x] [serial] Delete the 42 migrated package directories and four patches, move the Collie integration check into `flake-outputs/`, and remove obsolete excludes, test dependencies, and notes. r[onix.packages.onixpkgs]

## Phase 2: Verification

- [x] [serial] Compare every x86_64-linux machine toplevel, every x86_64-linux check, the dev shells, and the exported packages with the migration base, and explain each difference. r[onix.packages.onixpkgs]
- [x] [serial] Evaluate pine and utm-vm with the aarch64-linux wasm plugins built through qemu, before and after the migration. r[onix.packages.onixpkgs]
- [ ] [serial] Evaluate britton-air before and after the migration on a host with an aarch64-darwin builder. r[onix.packages.onixpkgs]
- [x] [serial] Validate this change with Cairn. r[onix.packages.onixpkgs]

## Phase 3: Publication

- [x] [serial] Switch the `onixpkgs` input from the local `git+file` URL to onixpkgs' published remote, `git+ssh://git@github.com/OnixResearch/onixpkgs.git`, and relock it. r[onix.packages.onixpkgs]

## Phase 4: Library and package updates

- [x] [serial] Build the changebot example and the kache checks with onixpkgs' `lib.kacheNixRust`, delete `lib/kache-nix-rust.nix`, and drop the wrapper contract check that onixpkgs now runs. r[onix.packages.kache_library]
- [x] [serial] Relock onixpkgs for iroh-ssh 0.2.12, the repaired horizon, and the kache library, and compare x86_64-linux machine toplevels and checks with the parent commit. r[onix.packages.onixpkgs] r[onix.packages.kache_library]
