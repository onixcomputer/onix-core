# Keycloak Terraform Integration Migration Guide

This guide explains how to migrate from the legacy cloud terraform approach to the new integrated Keycloak clan service with terraform support.

## Overview

### Before (Legacy Approach)
- Separate `cloud/keycloak-variables.nix` and `cloud/keycloak-admin-cli.nix` files
- Manual terraform configuration and state management
- Manual clan vars integration via devshell bridge
- Separate deployment of NixOS service and terraform resources

### After (Integrated Approach)
- Unified configuration through clan service interface
- Automatic terraform configuration generation
- Automatic clan vars bridge to terraform variables
- Single deployment workflow for both service and resources
- Type-safe configuration with proper validation
- Service discovery through exports

## Migration Steps

### 1. Update Clan Configuration

Replace your existing cloud terraform configuration with the new clan service approach:

```nix
# Old approach: cloud/infrastructure.nix
imports = [
  ./keycloak-variables.nix
  ./keycloak-admin-cli.nix
];

# New approach: inventory configuration
inventory.instances = {
  keycloak-production = {
    module.name = "keycloak";
    roles.server.machines.auth-server = {
      settings = {
        domain = "auth.robitzs.ch";
        terraform.enable = true;
        terraform.realms = { /* realm config */ };
        terraform.clients = { /* client config */ };
        # ... other terraform resources
      };
    };
  };
};
```

### 2. Migrate Resource Configurations

#### Realms Migration
```nix
# Old: cloud/keycloak-admin-cli.nix
resource.keycloak_realm.production = {
  realm = "production";
  enabled = true;
  display_name = "Production Environment";
  # ... other settings
};

# New: clan service configuration
terraform.realms = {
  production = {
    enabled = true;
    displayName = "Production Environment";
    # ... other settings (camelCase)
  };
};
```

#### Clients Migration
```nix
# Old: cloud/keycloak-admin-cli.nix
resource.keycloak_openid_client.web-app = {
  realm_id = "\${keycloak_realm.production.id}";
  client_id = "web-application";
  name = "Web Application";
  access_type = "CONFIDENTIAL";
  # ... other settings
};

# New: clan service configuration
terraform.clients = {
  web-app = {
    realm = "production";
    name = "Web Application";
    accessType = "CONFIDENTIAL";
    # ... other settings (camelCase, no realm_id needed)
  };
};
```

#### Variables Migration
```nix
# Old: cloud/keycloak-variables.nix - Manual variable definitions
variable.keycloak_admin_password = {
  type = "string";
  sensitive = true;
};

# New: Automatic variable bridge
# Variables are automatically generated from clan vars
# No manual variable definitions needed
```

### 3. Update Deployment Workflow

#### Old Workflow
```bash
# 1. Deploy clan service
clan machines deploy

# 2. Generate terraform config
cd cloud
terranix infrastructure.nix > main.tf.json

# 3. Load clan vars manually
KEYCLOAK_ADMIN_PASSWORD=$(clan vars get machine instance/admin_password)
echo "keycloak_admin_password = \"$KEYCLOAK_ADMIN_PASSWORD\"" >> terraform.tfvars

# 4. Apply terraform
tofu init && tofu apply
```

#### New Workflow
```bash
# 1. Deploy clan service (includes terraform config generation)
clan machines deploy

# 2. Apply terraform resources (vars automatically bridged)
ssh auth-server
cd /var/lib/keycloak-production-terraform
tofu init && tofu apply

# Or use unified devshell commands (if configured):
cloud keycloak apply production
```

### 4. Service Discovery Integration

The new approach provides automatic service discovery:

```nix
# Other services can now consume Keycloak configuration
otherService = {
  keycloakUrl = exports.instances.keycloak-production.keycloak.url;
  authUrl = exports.instances.keycloak-production.keycloak.terraform.realms.production.authUrl;
  clientId = "my-client";
};
```

## Configuration Mapping

### Attribute Name Changes
The new approach uses camelCase for better Nix integration:

| Old (terraform)           | New (clan service)        |
|---------------------------|---------------------------|
| `display_name`            | `displayName`             |
| `login_with_email_allowed`| `loginWithEmailAllowed`   |
| `registration_allowed`    | `registrationAllowed`     |
| `verify_email`            | `verifyEmail`             |
| `ssl_required`            | `sslRequired`             |
| `password_policy`         | `passwordPolicy`          |
| `access_type`             | `accessType`              |
| `standard_flow_enabled`   | `standardFlowEnabled`     |
| `valid_redirect_uris`     | `validRedirectUris`       |
| `web_origins`             | `webOrigins`              |

### Resource Reference Changes
```nix
# Old: Manual terraform references
realm_id = "\${keycloak_realm.production.id}";
client_id = "\${keycloak_openid_client.web-app.id}";

# New: Automatic reference generation
realm = "production";  # Automatically becomes realm_id reference
client = "web-app";    # Automatically becomes client_id reference
```

## Benefits of Migration

### 1. Simplified Configuration
- Single configuration file instead of multiple terraform files
- Type-safe options with validation
- Automatic reference resolution

### 2. Better Secret Management
- Automatic clan vars integration
- No manual variable bridging required
- Secure secret generation and deployment

### 3. Unified Deployment
- Single deployment command for service and resources
- Automatic terraform configuration generation
- Consistent state management

### 4. Service Discovery
- Automatic exports for other services
- Well-defined service interfaces
- Cross-service integration

### 5. Better Developer Experience
- IDE support with Nix language server
- Type checking and validation
- Comprehensive documentation

## Example Complete Migration

See `terraform-integration.nix` for a complete example that migrates all resources from the legacy `keycloak-admin-cli.nix` configuration to the new integrated approach.

## Troubleshooting

### Common Issues

1. **Attribute name mismatches**: Ensure you're using camelCase for the new attributes
2. **Missing realm references**: Specify the `realm` attribute for clients, users, etc.
3. **Variable conflicts**: Remove old terraform.tfvars files to avoid conflicts
4. **State conflicts**: Use separate terraform state for the new approach

### Validation

To validate your migration:
```bash
# Check clan configuration
nix eval .#nixosConfigurations.auth-server.config.clan.inventory

# Check generated terraform configuration
cat /var/lib/keycloak-production-terraform/main.tf.json | jq

# Verify service exports
nix eval .#nixosConfigurations.auth-server.config.clan.services.keycloak.exports
```