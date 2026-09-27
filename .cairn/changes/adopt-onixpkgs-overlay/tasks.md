## Phase 1: Implementation

- [x] [serial] Add the `onixpkgs` input, following onix-core's `nixpkgs`, `llm-agents`, `wrappers`, and `treefmt-nix`, and drop the `horizon` input that onixpkgs now owns. r[onix.packages.onixpkgs]
- [x] [serial] Apply the onixpkgs overlay in `shared-nix.nix`, `modules/dgx-machine`, and `flake-outputs/checks.nix`, and replace the seven `self.packages` injections. r[onix.packages.onixpkgs]
- [x] [serial] Point every module, profile, machine, check, and dev-shell reference to a migrated package at `pkgs.<name>` or `inputs'.onixpkgs.<name>`. r[onix.packages.onixpkgs]
- [x] [serial] Delete the 42 migrated package directories and four patches, move the Collie integration check into `flake-outputs/`, and remove obsolete excludes, test dependencies, and notes. r[onix.packages.onixpkgs]

## Phase 2: Verification

- [x] [serial] Compare every x86_64-linux machine toplevel, every x86_64-linux check, the dev shells, and the exported packages with the migration base, and explain each difference. r[onix.packages.onixpkgs]
- [ ] [serial] Compare pine, utm-vm, and britton-air with the migration base on a host that can build aarch64-linux wasm plugins and evaluate aarch64-darwin. r[onix.packages.onixpkgs]
- [x] [serial] Validate this change with Cairn. r[onix.packages.onixpkgs]

## Phase 3: Publication

- [x] [serial] Switch the `onixpkgs` input from the local `git+file` URL to onixpkgs' published remote, `git+ssh://git@github.com/OnixResearch/onixpkgs.git`, and relock it. r[onix.packages.onixpkgs]
