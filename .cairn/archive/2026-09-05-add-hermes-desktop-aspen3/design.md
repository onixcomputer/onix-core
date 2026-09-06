## Context

The repo installs LLM agent tooling through the managed `llm-agents` clan service, which maps the `llm-client` tag to `environment.systemPackages`. `aspen3` carries the `llm-client` tag and already receives `pi`, `openspec`, and `hermes-agent`. `aspen3` is brittonr's only interactive Niri desktop among the Aspen fleet, and `hermes-desktop` (an Electron app from the same pinned `llm-agents` input, version 0.7.6) provides the GUI companion to the Hermes agent.

Previously there was no desktop UI for Hermes on `aspen3`; `hermes-desktop` was not referenced anywhere in the repo, and `hermes-matrix-gateway` only runs on `britton-desktop`.

## Decisions

### 1. Extend the existing llm-agents service instance per machine

**Choice:** Add `machines.aspen3.settings.packages = ["hermes-desktop"]` to the `llm-agents` instance in `inventory/services/services.ncl`, keeping the role-level `settings.packages = ["pi", "openspec", "hermes-agent"]` untouched.

**Rationale:** Clan's service settings are evaluated through the NixOS module system, and `packages` is declared as `listOf str`, whose `listOf` merge concatenates definitions (verified experimentally against this repo's nixpkgs). A machine-level delta therefore adds `hermes-desktop` to `aspen3` without duplicating or disturbing the shared CLI set, and machines without the override (including all other `llm-client` hosts) keep exactly their current package set. The `ValidateSettings` contract already validates settings under `roles.<role>.machines.<machine>`, so the override is type-checked at `ncl export` time.

### 2. Keep the desktop app as a system-wide install

**Choice:** Install via `environment.systemPackages` through the service, not through a brittonr home-manager profile.

**Rationale:** `aspen3` is single-user (brittonr); a system package is identical in practice to a user install and keeps every Hermes component in one managed location. The `llm-agents` module already has no notion of user scope, so staying with the service avoids inventing a new per-user path for one package. The packaged app ships its own desktop entry and icon, so no manual desktop integration is needed.

### 3. Verify with contract fixtures and machine evaluation

**Choice:** Add positive and negative `llm-agents` settings fixtures wired into `_module-checks.nix`, and verify the evaluated `aspen3` configuration (package present) and `britton-desktop` configuration (unchanged) in the same rail.

**Rationale:** The repo's verification culture requires positive and negative coverage for every schema-driven service. A direct check of the evaluated configurations proves both the intended scope and the absence of accidental spread, which a fixture alone cannot prove.

## Risks / Trade-offs

- Upstream `hermes-desktop` pins Electron and rebuilds `better-sqlite3` at install; a future electron-major bump is guarded by the upstream package's own build-phase check (fails loudly rather than silently breaking). None identified for this change otherwise.
- The machine-level list delta relies on `listOf` concatenation semantics. If clan-core ever switches `packages` to a non-merging option type, the fixture and machine-evaluation checks in `_module-checks.nix` will fail loudly at `nix flake check` time.
