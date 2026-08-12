## Phase 1: Pin and compatibility boundary

- [x] [serial] Run the existing DGX tag, Mesh-LLM, service-registry, and Nickel export checks before core changes. r[onix.dgx_devenv.validation]
- [x] [serial] Add `devenv-machines` at `6e61f6a12f730b81228f70ee2487320fdbb1e2fc` without replacing the default-shell input. r[onix.dgx_devenv.pin]
- [x] [serial] Update `flake.lock` with the Nix lock command and review the scoped input changes. r[onix.dgx_devenv.pin]
- [x] [serial] Add a compatibility fixture for the reviewed NixOS machine options, metadata, build outputs, and CLI commands. r[onix.dgx_devenv.pin]
- [x] [serial] Wire only the required `nixpkgs`, Disko, facter, SecretSpec, and related follows into the canary input graph. r[onix.dgx_devenv.pin]

## Phase 2: Typed inventory and ownership

- [x] [serial] Define the DGX machine record and machine-map contracts in Nickel. r[onix.dgx_devenv.inventory]
- [x] [serial] Keep the production DGX machine map empty until real machine facts are available. r[onix.dgx_devenv.inventory]
- [x] [serial] Add deterministic Nickel export data for the experimental Devenv adapter. r[onix.dgx_devenv.inventory]
- [x] [serial] Add a freshness check that rejects stale generated data. r[onix.dgx_devenv.inventory]
- [x] [serial] Reject placeholders, empty fields, non-ARM systems, unstable disks, absent facter reports, and unowned loopback backends. r[onix.dgx_devenv.inventory] r[onix.dgx_devenv.storage] r[onix.dgx_devenv.services]
- [x] [serial] Add a pure machine-set comparison and reject names owned by both Devenv and Clan. r[onix.dgx_devenv.ownership]
- [x] [serial] Add positive and negative fixtures for complete records, empty production inventory, and duplicate ownership. r[onix.dgx_devenv.inventory] r[onix.dgx_devenv.ownership]

## Phase 3: Shared DGX NixOS policy

- [x] [serial] Extract the current DGX tag policy into a plain reusable NixOS module. r[onix.dgx_devenv.services]
- [x] [serial] Export the module as `nixosModules.dgxMachine` and make existing DGX checks consume it. r[onix.dgx_devenv.services]
- [x] [serial] Extract pure settings-to-Nix cores from Tailscale, iroh-ssh, and Mesh-LLM service shells. r[onix.dgx_devenv.services]
- [x] [serial] Keep Clan wrappers thin and prove that their evaluated behavior remains unchanged. r[onix.dgx_devenv.services]
- [x] [serial] Make the plain DGX module consume the same service cores and dynamic `tailscale0` bind logic. r[onix.dgx_devenv.services]
- [x] [serial] Configure Devenv SecretSpec bootstrap files and file-only Mesh-LLM join credentials. r[onix.dgx_devenv.secrets]
- [x] [serial] Force the Framework key as the only authorized key for `brittonr` and `root`. r[onix.dgx_devenv.access]
- [x] [serial] Add positive and negative module checks for service parity, backend ownership, runtime secrets, UID policy, and rejected keys. r[onix.dgx_devenv.services] r[onix.dgx_devenv.secrets] r[onix.dgx_devenv.access]

## Phase 4: Experimental Devenv adapter

- [x] [serial] Add a DGX-specific Devenv project module that lowers generated records into `machines.<name>`. r[onix.dgx_devenv.build]
- [x] [serial] Import the shared DGX NixOS module, Disko layout, facter report, target metadata, and system for each record. r[onix.dgx_devenv.services] r[onix.dgx_devenv.storage]
- [x] [serial] Keep experimental field names and metadata lowering in one adapter module. r[onix.dgx_devenv.pin]
- [x] [serial] Add synthetic machine fixtures for `machines info`, NixOS closure builds, and Disko script builds. r[onix.dgx_devenv.build] r[onix.dgx_devenv.storage]
- [x] [serial] Prove that the adapter does not add a real machine when production inventory is empty. r[onix.dgx_devenv.inventory]

## Phase 5: Device-free command shell

- [x] [serial] Add a repository-owned Rust command with pure argument and policy validation. r[onix.dgx_devenv.build]
- [x] [serial] Implement thin process shells for `dgx-machine info` and `dgx-machine build <name>`. r[onix.dgx_devenv.build]
- [x] [serial] Reject `deploy`, `install`, unknown commands, and undeclared names before the command starts a child process. r[onix.dgx_devenv.build]
- [x] [serial] Add positive tests for information and build command construction. r[onix.dgx_devenv.build]
- [x] [serial] Add negative tests for destructive commands, missing names, invalid names, and process errors. r[onix.dgx_devenv.build]
- [x] [serial] Expose the command as a flake app without adding the experimental CLI to the default shell. r[onix.dgx_devenv.pin] r[onix.dgx_devenv.build]

## Phase 6: Device-free evidence and documentation

- [x] [serial] Add a check that fails if a DGX validation command tries to use SSH or target activation. r[onix.dgx_devenv.validation]
- [x] [serial] Build every declared DGX closure and Disko script, or prove that the production map is intentionally empty. r[onix.dgx_devenv.validation]
- [x] [serial] Run positive and negative DGX, access, service, storage, ownership, and command checks. r[onix.dgx_devenv.validation]
- [x] [serial] Rerun the existing DGX tag, Mesh-LLM, service-registry, and Nickel export checks. r[onix.dgx_devenv.validation]
- [x] [serial] Document the exact canary revision, supported commands, required real-machine facts, and live-action prohibition. r[onix.dgx_devenv.pin] r[onix.dgx_devenv.build]
- [x] [serial] Add the Devenv machines pull request to the README references. r[onix.dgx_devenv.pin]
- [x] [serial] Record that install and deploy need a separate authorized Cairn change. r[onix.dgx_devenv.build] r[onix.dgx_devenv.storage]
- [ ] [serial] Run repository formatting, focused flake checks, Cairn validation, and proposal/design/tasks gates. r[onix.dgx_devenv.validation]
