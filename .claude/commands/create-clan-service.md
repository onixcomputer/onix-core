---
description: Create a new clan service with freeform options support
args:
  - name: service_name
    description: Name of the service (e.g., gitea, forgejo, nextcloud)
    required: true
  - name: nixos_source_url
    description: URL to NixOS service (GitHub source or nixos.org docs)
    required: true
---

Create a new clan service module for {{service_name}} based on {{nixos_source_url}}. Ultrathink and use subagents.

First, examine the NixOS service module at {{nixos_source_url}} to understand:
- Available configuration options
- Whether it's a web service, database service, or other type
- What secrets/credentials it requires
- Dependencies on other services

Follow the modern perInstance pattern with freeformType support as used by grafana, vaultwarden, prometheus, and matrix-synapse services.

Tasks:
1. Create module at modules/{{service_name}}/default.nix with:
   - freeformType = with lib; attrsOf anything
   - Clan-specific convenience options (identify from NixOS module)
   - perInstance pattern with extendSettings
   - Proper separation of clan vs freeform options

2. Register in modules/default.nix

3. Create inventory at inventory/services/{{service_name}}.nix with example configuration

4. Add to inventory/services/default.nix

5. Identify and implement clan conveniences based on the service type:
   - Web services: nginx reverse proxy with ACME
   - Database needs: PostgreSQL/MySQL setup
   - Secrets: Use clan.core.vars.generators for passwords/keys/tokens
   - User management if applicable

For secrets, use clan vars generators (https://docs.clan.lol/concepts/generators/):
```nix
clan.core.vars.generators = {
  "{{service_name}}-secret" = {
    prompts = { };  # No prompts for auto-generation
    migrateFact = "{{service_name}}-secret";  # Migration from facts
    script = { pkgs, ... }: ''
      ${pkgs.pwgen}/bin/pwgen -s 32 1 > "$out"/secret
    '';
    files."secret" = { };  # File that will be generated
  };
};
```

Then reference the generated secret:
```nix
config.clan.core.vars.generators.{{service_name}}-secret.files."secret".path
```

Template structure:
```nix
{
  _class = "clan.service";
  manifest.name = "{{service_name}}";

  roles = {
    server = {
      interface = { lib, ... }: {
        freeformType = with lib; attrsOf anything;
        
        options = {
          # Clan-specific options only
          # Examples: domain, enable_feature, database.type, users
        };
      };

      perInstance = { extendSettings, ... }: {
        nixosModule = { config, lib, pkgs, ... }:
          let
            settings = extendSettings { };
            # Extract clan options
            # inherit (settings) domain users ...;
            
            # Remove clan options from serviceConfig
            serviceConfig = builtins.removeAttrs settings [
              # List all clan-specific option names
            ];
          in
          {
            services.{{service_name}} = lib.mkMerge [
              { enable = true; }
              # Clan-managed defaults
              serviceConfig  # Freeform pass-through
            ];
            
            # Clan conveniences (nginx, database, etc.)
            
            # Secrets using clan vars
            clan.core.vars.generators = {
              # Define secrets here
            };
            
            # Reference secrets in systemd services
            systemd.services.{{service_name}} = {
              preStart = lib.mkAfter ''
                # Copy secrets to runtime locations
              '';
            };
          };
      };
    };
  };
}
```
