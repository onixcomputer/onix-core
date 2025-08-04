# Claude Commands

## Create New Clan Service with Freeform Options

### Slash Command Usage (Preferred):
```
/create-clan-service gitea https://nixos.org/manual/nixos/stable/options#opt-services.gitea.enable
```

This slash command is available in the `.claude/slash_commands/` directory and will automatically create a new clan service following the modern pattern.

### Manual Command (Alternative):
If the slash command is not available, you can use this manual command:

```
Create a new clan service with freeform options. 
Service name: [SERVICE_NAME]
NixOS service documentation: [NIXOS_SERVICE_URL]

Please:
1. Create the module at modules/[SERVICE_NAME]/default.nix using the modern perInstance pattern with freeformType
2. Register it in modules/default.nix
3. Create an inventory instance at inventory/services/[SERVICE_NAME].nix
4. Add it to inventory/services/default.nix
5. Identify key configuration options that should have clan-specific conveniences
6. Ensure proper separation between clan options and freeform NixOS service options
```

### Template for New Service Module

When creating a new service, use this template as a starting point:

```nix
{
  _class = "clan.service";
  manifest.name = "[SERVICE_NAME]";

  roles = {
    server = {
      interface = { lib, ... }: {
        freeformType = with lib; attrsOf anything;
        
        options = {
          # Add clan-specific options here
          # These should be high-level conveniences that configure multiple aspects
          # Examples: domain, enable_feature, database.type, users, etc.
        };
      };

      perInstance = { extendSettings, ... }: {
        nixosModule = { config, lib, pkgs, ... }:
          let
            # Get all settings
            settings = extendSettings { };
            
            # Extract clan-specific options
            # inherit (settings) option1 option2 ...;
            
            # Remove clan-specific options before passing to services.[SERVICE_NAME]
            serviceConfig = builtins.removeAttrs settings [
              # List all clan-specific option names here
            ];
          in
          {
            services.[SERVICE_NAME] = lib.mkMerge [
              {
                enable = true;
                # Set defaults based on clan options
              }
              # Pass through all freeform options
              serviceConfig
            ];
            
            # Additional clan conveniences (nginx, database, secrets, etc.)
            
            # Clan vars generators for secrets
            clan.core.vars.generators = {
              # Define any needed secrets
            };
          };
      };
    };
  };
}
```

### Key Principles:

1. **Freeform Support**: Use `freeformType = with lib; attrsOf anything` to allow any NixOS service option
2. **Clean Separation**: Clan options should be extracted and removed before passing to the NixOS service
3. **High-Level Conveniences**: Clan options should provide value beyond the NixOS service (e.g., automatic nginx setup, database configuration, secret management)
4. **Consistent Pattern**: Follow the same structure as Grafana, Vaultwarden, Prometheus, and Matrix Synapse services
5. **Documentation**: Include comments explaining clan-specific features and example configurations

### Common Clan Conveniences to Consider:

- **Web Services**: Automatic nginx reverse proxy with ACME certificates
- **Databases**: Automatic PostgreSQL/MySQL setup with user and database creation
- **Secrets**: Generation and management of API keys, passwords, tokens
- **Users**: Pre-configured user creation with appropriate permissions
- **Monitoring**: Prometheus metrics export configuration
- **Backup**: Integration with clan backup system
- **Networking**: Firewall rules and port management