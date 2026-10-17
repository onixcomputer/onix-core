## Phase 1: Implementation

- [x] [serial] Add the `hermes-agent` flake input (`github:NousResearch/hermes-agent`, nixpkgs follows) in `flake.nix` and regenerate `flake.lock` with `nix flake lock`. r[onix.hermes_agent.install] r[onix.hermes_agent.install.desktop] r[onix.hermes_agent.install.cli]
- [x] [serial] Add `inventory/home-profiles/brittonr/hermes/default.nix` importing the upstream Home Manager module with `programs.hermes-agent.enable = true` and `programs.hermes-agent.desktop.enable = true`, and wire it as an aspen3-only profile instance in `inventory/core/users.ncl`. r[onix.hermes_agent.install] r[onix.hermes_agent.install.desktop] r[onix.hermes_agent.install.cli]
- [x] [serial] Rework `inventory/services/services.ncl`: remove the aspen3 `hermes-desktop` delta, move `hermes-agent` out of the `llm-client` role list, and add per-machine `["hermes-agent"]` deltas for aspen1, aspen2, and britton-desktop. r[onix.hermes_agent.scope] r[onix.hermes_agent.scope.llm_client]
- [x] [serial] Remove the obsolete `llm-agents-validation.ncl` fixture and the `llm-agents-settings` check from `_module-checks.nix`; add official Hermes positive/negative machine checks to `_home-manager-checks.nix`. r[onix.hermes_agent.scope] r[onix.hermes_agent.scope.britton_desktop] r[onix.hermes_agent.scope.system] r[onix.hermes_agent.validation]

## Phase 2: Validation

- [x] [serial] Export the Nickel inventories (`inventory/services/services.ncl`, `inventory/core/users.ncl`) and verify the negative `packages` case. r[onix.hermes_agent.validation] r[onix.hermes_agent.validation.negative]
- [x] [serial] Build the pinned upstream `default` and `hermesDesktop` packages from the new input and run the focused home-manager and module flake checks. r[onix.hermes_agent.install] r[onix.hermes_agent.install.desktop] r[onix.hermes_agent.scope]
- [x] [serial] Run the Cairn proposal, design, and tasks gates, then `cairn validate`. r[onix.hermes_agent.validation]
