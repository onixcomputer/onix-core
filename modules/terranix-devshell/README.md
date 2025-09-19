# Terranix DevShell Module

A Clan service module that provides secure Terraform/OpenTofu infrastructure management with Terranix configuration.

## Features

- **Secure Credential Management**: All credentials loaded via systemd's `LoadCredential` mechanism
- **State Encryption**: Terraform state automatically encrypted and stored via Clan vars
- **Git-Relative Paths**: Working directories relative to git repository root
- **Multi-Provider Support**: Built-in support for Cloudflare, AWS, Azure, and Google Cloud
- **Terranix Integration**: Write infrastructure as Nix code, generate Terraform JSON

## Usage

### Basic Configuration

```nix
{
  services.terranix-devshell.infrastructure.enable = true;
  services.terranix-devshell.infrastructure.workingDirectory = "./infrastructure";
  services.terranix-devshell.infrastructure.cloudProviders = [ "cloudflare" ];
}
```

### Commands

After deployment, the following commands are available:

- `tfx init` - Initialize Terraform in the working directory
- `tfx plan` - Create an execution plan
- `tfx apply` - Apply infrastructure changes
- `tfx destroy` - Destroy infrastructure
- `tfx state` - Manage Terraform state
- `tfx build` - Build Terraform JSON from Terranix config

All commands use systemd-run for secure credential isolation.

### State Management

Terraform state is automatically:
1. Encrypted using Clan vars after each operation
2. Decrypted and loaded before each operation
3. Backed up via clan.core.state integration

### Credential Configuration

The module automatically creates Clan var generators for credentials:
- `terraform-state-{instance}` - For state encryption
- `cloudflare-{instance}` - For Cloudflare API tokens (if needed)
- `aws-{instance}` - For AWS credentials (if needed)

Set credentials using:
```bash
clan vars set $(hostname) terraform-state-infrastructure/tfstate
```

## Security

- All operations run in isolated systemd scopes
- Credentials loaded via systemd's `LoadCredential` mechanism
- State never stored unencrypted on disk
- Automatic cleanup of temporary files

## File Structure

```
modules/terranix-devshell/
├── default.nix          # Main module implementation
├── README.md            # This file
└── ENCRYPTED_STATE.md   # Detailed state encryption documentation
```