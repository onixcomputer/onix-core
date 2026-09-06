# Install Official Hermes Agent Desktop on aspen3

## Context

`aspen3` is brittonr's interactive Niri desktop. On 2026-09-05 the repo installed `hermes-desktop` from the `llm-agents` flake (fathah) for aspen3 because it was thought to be the Hermes desktop application. The official product is `NousResearch/hermes-agent`, shipped by Nous Research with its own website, Nix flake, NixOS module, and Home Manager module. The upstream Home Manager module separates installation from daemons: `programs.hermes-agent.enable` installs the CLI, `programs.hermes-agent.desktop.enable` installs the Electron Hermes Desktop with a Linux XDG launcher, and `services.hermes-agent.*` manages state, config, and daemons. The repo already runs the upstream Hermes messaging gateway through its own `hermes-gateway` module on britton-desktop; aspen3 runs no Hermes daemon today.

## Decisions

### 1. Use the upstream Home Manager module, install-only

**Choice:** Import `inputs.hermes-agent.homeManagerModules.default` into a new aspen3-only `hermes` home-manager profile for brittonr and enable `programs.hermes-agent.enable = true` plus `programs.hermes-agent.desktop.enable = true`. Do not enable `services.hermes-agent` or a gateway.

**Rationale:** The upstream module gives the exact Hermes Desktop the user asked for, with the launcher carrying `HERMES_HOME` correctly (a GUI menu reads no shell profile). The download-and-run flow of the official site is the reference behavior. Leaving the service layer disabled keeps brittonr's first-run interactive setup (`hermes setup --portal`) working — the service layer installs a `.managed` marker that blocks `hermes setup` / `hermes config set` — and requires no provider choice, model pin, or API-key wiring that the user has not specified. The desktop starts its own loopback backend by design when no shared session token is configured. Re-implementing the desktop packaging in onix-core would duplicate upstream maintenance for no benefit.

### 2. Replace the community package on aspen3

**Choice:** Remove the `machines.aspen3.settings.packages = ["hermes-desktop"]` delta from the `llm-agents` service, and change the role package list from `["pi", "openspec", "hermes-agent"]` to `["pi", "openspec"]`, adding per-machine `["hermes-agent"]` deltas for `aspen1`, `aspen2`, and `britton-desktop`.

**Rationale:** ServoC-collected `listOf` settings concatenate role-level and machine-level definitions (verified against this repo's nixpkgs). Removing `hermes-agent` from the role list and re-adding it per-machine for the other three `llm-client` hosts keeps their effective set byte-identical while aspen3 receives no CLI package from the role. aspen3's Hermes comes only from the official home-manager install, so there is one `hermes` on the user's PATH instead of two shadowing each other. This also removes the fattha hermes-desktop system package the earlier change deployed, avoiding two `hermes-desktop` launchers.

### 3. Keep the shared llm-client effective set unchanged elsewhere

**Choice:** Do not change what aspen1, aspen2, or britton-desktop receive from `llm-agents`.

**Rationale:** The `hermes-matrix-gateway` on britton-desktop consumes `inputs.llm-agents.packages.hermes-agent` directly and is independent of `environment.systemPackages`. Preserving the exact prior effective set for the other hosts makes this change strictly additive for them and reduces blast radius to aspen3.

### 4. Verify through home-manager machine evaluation

**Choice:** Add positive and negative checks in `flake-outputs/_home-manager-checks.nix` that evaluate the aspen3 and britton-desktop home-manager configurations for brittonr, and re-verify the aspen3 system package set. Remove the previous `llm-agents-validation.ncl` fixture and the `llm-agents-settings` check from `_module-checks.nix`, which only covered the replaced community package.

**Rationale:** The repo's verification culture requires positive and negative coverage. A direct evaluation of both machines proves the aspen3-only scope that a schema fixture alone cannot prove. Keeping the shared role negative checks for the other machines guards the per-machine deltas from drift.

## Risks / Trade-offs

- The upstream flake is Tier 2 best-effort; a future `main` update can break package or module shapes. The flake's own checks exercise the module; onix-core only pins the input revision through the lockfile.
- The `default` package closure is large (all optional integrations). This is the price of a self-contained desktop app and matches upstream's recommended install.
- Keeping the service layer disabled means the agent's config and state are not Nix-managed on aspen3 yet. If brittonr wants a declarative gateway or backend later, enable `services.hermes-agent` and add `settings` / `environmentFiles` as a follow-on change.
- Trusting `listOf` concatenation and the upstream module's behavior is bounded by the new machine-scoping checks, which fail loudly at `nix flake check`.
