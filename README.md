🚧🚧🚧 Under construction! Not for use *yet*™ 🚧🚧🚧

# Onix Infrastructure

A declarative NixOS infrastructure repository powered by [clan-core](https://clan.lol), implementing tag-based service deployment and modular home-manager configurations.

## Architecture Overview

This repository manages NixOS machines using upstream clan-core with a structured approach to user and home configuration management.

### Core Components

**User Management**: Users are defined through two mechanisms:

- **Upstream `users` module** — password generation and group membership via clan-core's `users` service
- **Local NixOS config** (`inventory/tags/all.nix`) — UID, shell, SSH keys applied to all machines

**Tag-Based System**: Services and configurations deploy based on machine tags:

- `all` — Base configurations for every NixOS machine
- `hm-server` / `hm-laptop` — Home-manager profile groups
- `tailnet-*` — Tailscale VPN connectivity
- `dev` — Development tools and environments
- `desktop` — Desktop environment configurations

**Home-Manager Profiles**: Modular HM configurations in `inventory/home-profiles/<user>/<profile>/`:

- `base/` — Core utilities (editor, shell, git)
- `dev/` — Development tools (direnv, language toolchains)
- `noctalia/` — Desktop theme and compositor config
- `creative/` — Creative tools
- `social/` — Communication apps

Machines get profiles via tags: `hm-server` (base+dev), `hm-laptop` (base+dev+noctalia+social), or direct machine assignment for custom combos.

## Project Structure

```
.
├── flake.nix                # Nix flake entry point
├── inventory/               # Infrastructure definitions
│   ├── core/               # Machine defs, user instances
│   ├── services/           # Service instances
│   ├── tags/               # Tag-based configurations
│   └── home-profiles/      # User home-manager profiles
├── machines/               # Machine-specific NixOS configs
├── modules/                # Custom clan service modules
├── parts/                  # Flake parts for modularity
└── vars/                   # SOPS-encrypted variables
```

## Getting Started

```bash
# Enter development environment
nix develop

# List all machines
clan machines list

# Deploy to a specific machine
clan machines update <machine-name>
```
