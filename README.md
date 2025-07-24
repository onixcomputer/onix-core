# Onix Infrastructure

A declarative NixOS infrastructure repository powered by [clan-core](https://clan.lol), implementing advanced user and machine management with integrated home configurations.

## Architecture Overview

This repository manages NixOS machines with a holistic approach to user and home configuration management. The infrastructure provides centralized user definitions with per-machine customization, integrated home-manager profiles, and tag-based service deployment.

### Core Components

**User Management**: Unified user management across all machines, combining:
- Centralized user definitions with global attributes (UID, groups, SSH keys)
- Per-machine user customization (roles, shells, home-manager profiles)
- Modular home-manager configurations organized by user and profile type
- Role-based access control (owner, admin, basic, service)

**Tag-Based System**: Services and configurations deploy based on machine tags:
- `all` - Base configurations for every machine
- `tailnet` - Tailscale VPN connectivity
- `home-manager` - User home environment management
- `dev` - Development tools and environments
- `desktop` - Desktop environment configurations
- `wsl` - Windows Subsystem for Linux specific settings

**Infrastructure Components**:
- Manages physical, virtual, and WSL environments
- Multi-user support with distinct preferences and toolchains
- Tailscale mesh networking for zero-config connectivity
- SOPS-encrypted secrets with clan vars integration
- Declarative disk management with disko

## Project Structure

```
.
├── flake.nix                # Nix flake entry point
├── inventory/               # Infrastructure definitions
│   ├── core/               # Machine and user definitions
│   ├── services/           # Service instances
│   ├── tags/               # Tag-based configurations
│   └── home-profiles/      # User home-manager profiles
├── machines/               # Machine-specific NixOS configs
├── modules/                # Custom clan service modules
├── parts/                  # Flake parts for modularity
└── vars/                   # SOPS-encrypted variables
```

## User and Home Management

The infrastructure enables sophisticated user management patterns:

1. **Global User Definition** (`inventory/core/users.nix`):
   ```nix
   username = {
     defaultUid = 1000;
     defaultGroups = ["audio", "networkmanager", "video"];
     sshAuthorizedKeys = [...];
   };
   ```

2. **Per-Machine Configuration**:
   ```nix
   machines.hostname = {
     role = "owner";
     shell = "zsh";
     homeManager = {
       enable = true;
       profiles = ["base", "desktop", "dev"];
     };
   };
   ```

3. **Modular Home Profiles** (`inventory/home-profiles/<user>/<profile>/`):
   - `base/` - Core utilities (editor, shell, git)
   - `dev/` - Development tools (direnv, language toolchains)
   - `desktop/` - GUI applications (browsers, desktop apps)

## Getting Started

```bash
# Enter development environment
nix develop

# List all machines
clan machines list

# Deploy to a specific machine
clan machines update <machine-name>
```
