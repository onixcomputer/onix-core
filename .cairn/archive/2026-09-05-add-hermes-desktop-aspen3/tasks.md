## Phase 1: Implementation

- [x] [serial] Add `machines.aspen3.settings.packages = ["hermes-desktop"]` to the `llm-agents` service instance in `inventory/services/services.ncl`, with a `# r[impl onix.hermes_desktop.install]` traceability marker, keeping the role-level package list unchanged. r[onix.hermes_desktop.install] r[onix.hermes_desktop.install.aspen3] r[onix.hermes_desktop.install.scope]
- [x] [serial] Add `inventory/services/fixtures/llm-agents-validation.ncl` with positive and negative `llm-agents` role settings cases and wire them into `flake-outputs/_module-checks.nix`. r[onix.hermes_desktop.validation]

## Phase 2: Validation

- [x] [serial] Validate the Nickel inventory contracts (`ncl export inventory/services/services.ncl`) and build the `hermes-desktop` package from the pinned `llm-agents` input. r[onix.hermes_desktop.install] r[onix.hermes_desktop.validation]
- [x] [serial] Evaluate the `aspen3` and `britton-desktop` configurations and confirm the machine-scoping assertion (present on `aspen3`, absent on `britton-desktop`) through the `_module-checks.nix` rail. r[onix.hermes_desktop.install.aspen3] r[onix.hermes_desktop.install.scope]
- [x] [serial] Run the Cairn proposal, design, and tasks gates, then `cairn validate`, then run the focused `nix flake check` sub-targets for the change. r[onix.hermes_desktop.validation]
