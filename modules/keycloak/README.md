# Keycloak Clan Service with Terraform Integration

A comprehensive Keycloak service for the Clan framework with integrated Terraform resource management.

## Overview

This module provides a complete Keycloak identity and access management solution that combines:

- **NixOS Service**: Full Keycloak deployment with PostgreSQL backend and nginx reverse proxy
- **Terraform Integration**: Automatic generation and management of Keycloak resources (realms, clients, users, groups, roles)
- **Clan Variables**: Secure secret management with automatic generation and deployment
- **Service Discovery**: Exports for cross-service integration

## Features

### Core Service
- ✅ Keycloak server with PostgreSQL database
- ✅ Nginx reverse proxy with proper headers
- ✅ Automatic password generation and management
- ✅ Instance-specific configuration support
- ✅ Service startup ordering and health checks

### Terraform Integration
- ✅ Automatic terraform configuration generation
- ✅ Comprehensive resource support (realms, clients, users, groups, roles)
- ✅ Variable bridge between clan vars and terraform
- ✅ Management scripts for terraform operations
- ✅ State management and backend configuration

### Developer Experience
- ✅ Type-safe configuration with Nix
- ✅ Unified devshell commands
- ✅ Migration guides and examples
- ✅ Comprehensive documentation

## Quick Start

### 1. Basic Service Deployment

```nix
# In your clan configuration
inventory.instances = {
  keycloak-production = {
    module.name = "keycloak";
    roles.server.machines.auth-server = {
      settings = {
        domain = "auth.example.com";
        nginxPort = 9080;
      };
    };
  };
};
```

### 2. With Terraform Integration

```nix
inventory.instances = {
  keycloak-production = {
    module.name = "keycloak";
    roles.server.machines.auth-server = {
      settings = {
        domain = "auth.example.com";
        nginxPort = 9080;

        terraform = {
          enable = true;

          realms = {
            production = {
              displayName = "Production Environment";
              registrationAllowed = false;
              verifyEmail = true;
            };
          };

          clients = {
            web-app = {
              realm = "production";
              name = "Web Application";
              accessType = "CONFIDENTIAL";
              validRedirectUris = ["https://app.example.com/auth/callback"];
            };
          };

          users = {
            admin = {
              realm = "production";
              email = "admin@example.com";
              firstName = "System";
              lastName = "Administrator";
              initialPassword = "ChangeMe123!";
            };
          };
        };
      };
    };
  };
};
```

## Deployment

### Service Deployment
```bash
# Deploy the clan service (includes terraform config generation)
clan machines deploy auth-server
```

### Terraform Resource Management
```bash
# Option 1: Use devshell commands (recommended)
cloud keycloak-service status keycloak-production
cloud keycloak-service deploy keycloak-production

# Option 2: SSH to the machine and use management script
ssh auth-server
cd /var/lib/keycloak-production-terraform
./manage.sh init
./manage.sh plan
./manage.sh apply
```

## Configuration Reference

### Basic Settings

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `domain` | string | required | Domain name for the Keycloak instance |
| `nginxPort` | port | 9080 | Nginx proxy port |

### Terraform Integration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `terraform.enable` | bool | false | Enable terraform resource management |
| `terraform.realms` | attrs | {} | Keycloak realms configuration |
| `terraform.clients` | attrs | {} | OIDC clients configuration |
| `terraform.users` | attrs | {} | Users configuration |
| `terraform.groups` | attrs | {} | Groups configuration |
| `terraform.roles` | attrs | {} | Roles configuration |

### Realm Configuration

```nix
terraform.realms.my-realm = {
  enabled = true;
  displayName = "My Realm";
  loginWithEmailAllowed = true;
  registrationAllowed = false;
  verifyEmail = true;
  sslRequired = "external";
  passwordPolicy = "upperCase(1) and length(8) and notUsername";

  # Session settings
  ssoSessionIdleTimeout = "30m";
  ssoSessionMaxLifespan = "10h";

  # Themes
  loginTheme = "base";
  adminTheme = "base";

  # Internationalization
  internationalization = {
    supportedLocales = ["en" "de" "fr"];
    defaultLocale = "en";
  };
};
```

### Client Configuration

```nix
terraform.clients.my-client = {
  realm = "my-realm";
  name = "My Application";
  description = "Main application client";

  # Security settings
  accessType = "CONFIDENTIAL";  # or "PUBLIC" for mobile apps
  standardFlowEnabled = true;
  directAccessGrantsEnabled = false;
  serviceAccountsEnabled = false;  # true for API clients

  # URLs
  validRedirectUris = ["https://app.example.com/auth/callback"];
  validPostLogoutRedirectUris = ["https://app.example.com/logout"];
  webOrigins = ["https://app.example.com"];

  # Security enhancements
  pkceCodeChallengeMethod = "S256";
};
```

### User Configuration

```nix
terraform.users.john-doe = {
  realm = "my-realm";
  email = "john.doe@example.com";
  firstName = "John";
  lastName = "Doe";
  enabled = true;
  emailVerified = true;

  attributes = {
    department = "Engineering";
    role = "developer";
  };

  initialPassword = "TempPassword123!";
  temporary = true;  # User must change on first login
};
```

## Service Exports

The service automatically exports configuration for other services to consume:

```nix
# Other services can access Keycloak configuration
otherService = {
  keycloakUrl = exports.instances.keycloak-production.keycloak.url;
  authUrl = exports.instances.keycloak-production.keycloak.terraform.realms.production.authUrl;
  tokenUrl = exports.instances.keycloak-production.keycloak.terraform.realms.production.tokenUrl;
};
```

Available exports:
- `url`: Keycloak base URL
- `adminConsoleUrl`: Admin console URL
- `terraform.realms.<name>`: Realm-specific URLs (auth, token, userinfo, jwks, issuer)
- `terraform.clients.<name>`: Client information

## DevShell Commands

### Integrated Mode Commands
```bash
# Show service status
cloud keycloak-service status keycloak-production

# Deploy service and show terraform instructions
cloud keycloak-service deploy keycloak-production

# Show terraform management instructions
cloud keycloak-service terraform keycloak-production
```

### Legacy Mode Commands
```bash
# Create specific resources
cloud keycloak create realm my-realm
cloud keycloak create client my-client

# Check resource status
cloud keycloak status realm my-realm
cloud keycloak status client

# Destroy resources
cloud keycloak destroy user john-doe
```

## Migration from Legacy Approach

### Before (Legacy)
- Separate `cloud/keycloak-*.nix` files
- Manual terraform configuration
- Manual clan vars integration
- Separate deployment workflows

### After (Integrated)
- Single clan service configuration
- Automatic terraform generation
- Built-in variable bridge
- Unified deployment

See `examples/MIGRATION.md` for detailed migration instructions.

## Examples

- `examples/terraform-integration.nix` - Complete example with all resource types
- `examples/MIGRATION.md` - Migration guide from legacy approach
- `../cloud/infrastructure-integrated.nix` - Integrated infrastructure example

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Clan Service Module                        │
├─────────────────────────────────────────────────────────────────┤
│  Interface Options                                              │
│  ├── Basic Settings (domain, port)                             │
│  └── Terraform Configuration (realms, clients, users, etc.)    │
├─────────────────────────────────────────────────────────────────┤
│  Per Instance                                                   │
│  ├── NixOS Module                                              │
│  │   ├── Keycloak Service                                      │
│  │   ├── PostgreSQL Database                                   │
│  │   ├── Nginx Reverse Proxy                                   │
│  │   └── Clan Variables (secrets)                             │
│  ├── Terraform Integration (when enabled)                      │
│  │   ├── Configuration Generation                              │
│  │   ├── Variable Bridge                                       │
│  │   └── Management Scripts                                    │
│  └── Service Exports                                           │
│      ├── Service URLs                                          │
│      └── Terraform Resource Info                              │
└─────────────────────────────────────────────────────────────────┘
```

## Security Best Practices

1. **Use HTTPS**: Always configure with proper SSL/TLS certificates
2. **Strong Passwords**: Use the built-in password generation
3. **PKCE**: Enable PKCE for public clients (mobile apps)
4. **Realm Isolation**: Use separate realms for different environments
5. **Regular Updates**: Keep Keycloak and dependencies updated

## Troubleshooting

### Common Issues

1. **Service not starting**: Check PostgreSQL readiness and port conflicts
2. **Terraform variables not found**: Ensure clan vars are generated and deployed
3. **Authentication failures**: Verify admin password and URL configuration
4. **Resource conflicts**: Use separate terraform state for different instances

### Debugging

```bash
# Check service status
systemctl status keycloak

# View service logs
journalctl -u keycloak -f

# Check terraform configuration
cat /var/lib/keycloak-production-terraform/main.tf.json

# Validate terraform
cd /var/lib/keycloak-production-terraform
./manage.sh plan
```

## Contributing

When contributing to this module:

1. Follow existing code patterns and conventions
2. Update documentation for any new options
3. Add examples for new features
4. Test with both legacy and integrated approaches
5. Update migration guides as needed

## License

This module is part of the onix-core project and follows the same license terms.