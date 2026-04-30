## ADDED Requirements

### Requirement: all inputs that depend on disko follow our disko
The `clan-core` input SHALL have `inputs.disko.follows = "disko"`, and `disko` SHALL be declared as a top-level input with `inputs.nixpkgs.follows = "nixpkgs"`.

#### Scenario: single disko in lock file
- **WHEN** `nix flake metadata` is inspected
- **THEN** there is exactly one disko input node (no nested duplicates)

### Requirement: all inputs that depend on sops-nix follow our sops-nix
The `clan-core` input SHALL have `inputs.sops-nix.follows = "sops-nix"`, and `sops-nix` SHALL be declared as a top-level input with `inputs.nixpkgs.follows = "nixpkgs"`.

#### Scenario: single sops-nix in lock file
- **WHEN** `nix flake metadata` is inspected
- **THEN** there is exactly one sops-nix input node

### Requirement: all inputs that depend on systems follow our systems
A `systems` input SHALL be declared at top level (`github:nix-systems/default`). All inputs that accept a `systems` input (llm-agents, buildbot-nix, etc.) SHALL have `inputs.systems.follows = "systems"`.

#### Scenario: single systems input in lock
- **WHEN** `nix flake metadata` is inspected
- **THEN** there is exactly one systems input node

### Requirement: all inputs that depend on home-manager follow our home-manager
Inputs that accept a `home-manager` input SHALL have `inputs.home-manager.follows = "home-manager"` where applicable.

#### Scenario: no duplicate home-manager in lock
- **WHEN** `nix flake metadata` is inspected
- **THEN** there is at most one home-manager input node

### Requirement: heavy git inputs use shallow clones
Inputs fetched via `git+https://` that are large repositories SHALL use `?shallow=1` to avoid full history fetches. This applies to at least: `clan-core`, `buildbot-nix`.

#### Scenario: clan-core uses shallow clone
- **WHEN** the flake.nix `clan-core` input URL is inspected
- **THEN** the URL contains `?shallow=1` (or `&shallow=1` if other params present)

#### Scenario: flake update is faster
- **WHEN** `nix flake update` fetches clan-core
- **THEN** only a shallow clone is performed (no full git history)

### Requirement: nixpkgs follows threaded through all inputs
Every input that accepts a `nixpkgs` input SHALL have `inputs.nixpkgs.follows = "nixpkgs"`. No input SHALL bring its own pinned nixpkgs.

#### Scenario: audit finds no duplicate nixpkgs
- **WHEN** `nix flake metadata --json` is parsed for all input nodes
- **THEN** every reference to nixpkgs resolves to the same top-level nixpkgs node
