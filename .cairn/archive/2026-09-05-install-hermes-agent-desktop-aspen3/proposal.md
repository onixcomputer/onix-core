## Why

The previous `add-hermes-desktop-aspen3` change installed `hermes-desktop` from the `llm-agents` flake (`fathah/hermes-desktop`), a community-made Electron "Desktop companion". The official Hermes product is the agent from `NousResearch/hermes-agent` (hermes-agent.nousresearch.com). Its distribution includes the real **Hermes Desktop** application — an Electron shell that connects to the agent's own backend — plus a first-class Nix flake with a Home Manager module and a declarative `programs.hermes-agent.desktop.enable` option. The user wants the official Hermes Agent Desktop on aspen3, not the community companion.

## What Changes

- Add `github:NousResearch/hermes-agent` as a flake input (`inputs.nixpkgs` follows our nixpkgs).
- Install the official Hermes Agent for brittonr on aspen3 through the upstream Home Manager module: `programs.hermes-agent.enable = true` (the `hermes` CLI) and `programs.hermes-agent.desktop.enable = true` (the Hermes Desktop Electron app with a Linux launcher entry). Configuration lives in a new aspen3-only `hermes` home-manager profile wired through the existing per-machine profile mechanism.
- Remove the previous aspen3-only `hermes-desktop` (fathah) override from the `llm-agents` service so aspen3 does not carry two conflicting Hermes desktop applications.
- Move the CLI-only `hermes-agent` out of the shared `llm-client` package role list and pin it back onto the other three `llm-client` machines (`aspen1`, `aspen2`, `britton-desktop`) via per-machine deltas. aspen3 then uses the official install only — one `hermes`, no shadowing.
- Remove the now-obsolete `llm-agents-validation.ncl` fixture and the machine-scoping check for the community package from `_module-checks.nix`; add official Hermes positive/negative coverage to `_home-manager-checks.nix` instead.

## Impact

- **Files**: `flake.nix`, `flake.lock`, `inventory/services/services.ncl`, `inventory/core/users.ncl`, `inventory/home-profiles/brittonr/hermes/default.nix`, `flake-outputs/_module-checks.nix`, `flake-outputs/_home-manager-checks.nix`, removal of `inventory/services/fixtures/llm-agents-validation.ncl`, `.cairn/` change package.
- **Risk**: The upstream flake is a Tier 2 "best-effort" Nix platform; package and module shapes can break on upstream `main` updates. The desktop build compiles Electron + node-pty from source and the `default` package adds roughly 700 MB to the closure. No new services, secrets, or daemons are enabled — brittonr keeps full interactive setup (`hermes setup`) because the Home Manager service layer stays disabled.
- **Non-goals**: No messaging gateway, no declarative `services.hermes-agent` daemon on aspen3 (follow-on work; the desktop starts its own local backend), no change to the onix-core `hermes-gateway` Matrix module on britton-desktop, no change to the other `llm-client` machines' effective package set.
- **Testing**: Nickel export of the service and user inventories, build the pinned upstream `default` and `hermesDesktop` packages, evaluate the aspen3 and britton-desktop home-manager configurations with a positive/negative scope check, run the existing focused flake checks, then the Cairn gates and validate.
