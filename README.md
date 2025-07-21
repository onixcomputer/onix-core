# Clan Infrastructure

A declarative NixOS infrastructure repository powered by [clan-core](https://clan.lol), providing scalable machine and user management through a tag-based deployment system.

## Features

- 🏷️ **Tag-based deployment** - Services and configurations deploy based on machine tags
- 👥 **Centralized user management** - Role-based access control across all machines
- 🏠 **Per-user environments** - Home-manager configurations organized by user and tags
- 🔐 **Secure secrets** - SOPS-encrypted secrets with clan vars integration
- 🌐 **Tailscale networking** - Zero-config VPN connectivity between machines
- 🛠️ **Developer friendly** - Integrated formatting, linting, and pre-commit hooks

## Quick Start

```bash
# Enter development environment
nix develop

# List all machines
clan machines list

# Deploy to a machine
clan machines update <machine-name>

# Generate user password
clan secrets generate user-password-<username>
```

## Project Structure

```
.
├── flake.nix                # Nix flake entry point
├── inventory/               # Declarative infrastructure definitions
│   ├── core/               # Machine and user definitions
│   ├── services/           # Service instances (tailscale, ssh, etc.)
│   ├── tags/               # System-wide configs by machine tag
│   └── home-profiles/      # User home-manager configurations
├── machines/               # Machine-specific NixOS configurations
├── modules/                # Custom clan service modules
├── parts/                  # Flake parts for modularity
└── vars/                   # SOPS-encrypted secrets (managed by clan)
```

See `inventory/STRUCTURE.md` for detailed architecture documentation.

## How It Works

### Tag-Based Deployment
Machines receive configurations and services based on their assigned tags:
- `all` - Applied to every machine (implicit)
- `home-manager` - Enables user home configurations
- `dev` - Development tools and environments
- `desktop` - Desktop environments (Hyprland, etc.)
- `physical` - Physical hardware specific configs
- Custom tags for specific services or roles

### Service Architecture
All services follow the clan service pattern with:
- Declarative instance definitions in `inventory/services/`
- Role-based deployment using machine tags
- Modular, reusable service modules in `modules/`

### User Management
Users are defined once and deployed across machines with role-based permissions:
- `owner` - Full sudo access with password generation
- `admin` - Sudo access without password generation
- `basic` - Regular user without sudo
- `service` - System service accounts

## Development

```bash
# Format all code
nix fmt

# Run checks
nix flake check

# Build a machine configuration
nix build .#nixosConfigurations.<machine>
```

## Common Tasks

### Add a New Machine
```bash
# 1. Define machine in inventory/core/machines.nix
# 2. Create machines/<name>/configuration.nix
# 3. Assign users in inventory/core/users.nix
# 4. Deploy
clan machines update <machine-name>
```

### Add a New User
```bash
# 1. Define user in inventory/core/users.nix
# 2. Create home-profiles/<username>/base/ for configs
# 3. Generate password
clan secrets generate user-password-<username>
```

### Add a Service
```bash
# 1. Create module in modules/<service>/ (if custom)
# 2. Define instance in inventory/services/<service>.nix
# 3. Tag target machines in inventory/core/machines.nix
```

## Documentation

- `CLAUDE.md` - Comprehensive development guide and AI collaboration patterns
- `inventory/STRUCTURE.md` - Detailed inventory architecture documentation
- `inventory/home-profiles/README.md` - Home-manager configuration guide

## License

This infrastructure repository is maintained for private use. See individual component licenses for clan-core and other dependencies.
