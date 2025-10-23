# Keycloak Terranix Module

A comprehensive, type-safe terranix module for managing Keycloak resources with proper NixOS-style patterns, validation, and modular organization.

## Architecture Overview

This module follows NixOS module patterns with `{ config, lib, ... }:` structure, providing:

- **Type-safe configuration** with comprehensive option types and validation
- **Modular organization** - separate modules for different resource types
- **Cross-resource validation** - dependency checking and relationship validation
- **Resource relationship handling** - proper terraform resource dependencies
- **Enterprise-grade features** - comprehensive coverage of Keycloak functionality

## Module Structure

```
terranix/
├── default.nix          # Main module with provider config and global settings
├── provider.nix         # Keycloak provider configuration
├── realms.nix          # Realm management with comprehensive options
├── clients.nix         # OAuth/OIDC client configuration
├── users.nix           # User management with attributes and roles
├── groups.nix          # Group hierarchy and role assignments
├── roles.nix           # Realm and client role management
├── client-scopes.nix   # Client scope and protocol mapper configuration
├── validation.nix      # Cross-resource validation and dependency checking
├── example.nix         # Complete usage example
└── README.md           # This documentation
```

## Key Features

### 1. NixOS-Style Module Patterns

All modules follow the standard NixOS pattern:

```nix
{ config, lib, ... }:
let
  inherit (lib) mkOption mkIf types;
  cfg = config.services.keycloak;
in
{
  options.services.keycloak = {
    # Comprehensive options with types, defaults, descriptions, examples
  };

  config = mkIf cfg.enable {
    # Terraform resource generation
  };
}
```

### 2. Comprehensive Type System

- **Base types**: Non-empty strings, URLs, durations, enums
- **Resource references**: Type-safe references between resources
- **Validation types**: PKCE methods, SSL requirements, access types
- **Composite types**: Complex submodules for nested configuration

### 3. Cross-Resource Validation

The validation module provides:

- **Reference validation**: Ensures all referenced resources exist
- **Hierarchy validation**: Prevents circular dependencies in groups
- **Uniqueness validation**: Ensures unique names within realms
- **Security validation**: PKCE for public clients in strict mode
- **Build-time validation**: Fails fast with clear error messages

### 4. Resource Relationship Handling

- **Automatic dependencies**: Terraform resource references are generated automatically
- **Composite roles**: Support for role composition with proper dependencies
- **Group hierarchies**: Parent-child relationships with validation
- **Protocol mappers**: Automatic mapper generation for clients and scopes

## Usage

### Basic Configuration

```nix
{
  services.keycloak = {
    enable = true;

    # Provider configuration
    provider = {
      url = "https://auth.company.com";
      username = "admin";
      password = "\${var.admin_password}";
    };

    # Global settings
    settings = {
      resourcePrefix = "prod_";
      validation.enableCrossResourceValidation = true;
    };

    # Define variables
    variables = {
      admin_password = {
        description = "Keycloak admin password";
        sensitive = true;
      };
    };

    # Create a realm
    realms.company = {
      displayName = "Company Realm";
      enabled = true;
      registrationAllowed = true;
      loginWithEmailAllowed = true;
    };

    # Create a client
    clients.web-app = {
      realmId = "company";
      accessType = "CONFIDENTIAL";
      standardFlowEnabled = true;
      validRedirectUris = [ "https://app.company.com/*" ];
      pkceCodeChallengeMethod = "S256";
    };
  };
}
```

### Advanced Configuration

See `example.nix` for a comprehensive configuration demonstrating:

- Multiple realms with different settings
- Complex client configurations (web, mobile, API)
- Role hierarchies and composition
- Group management with inheritance
- User creation with attributes and role assignments
- Client scopes with protocol mappers
- SMTP configuration for email sending
- WebAuthn policies for security keys

### Resource Types

#### Realms

Comprehensive realm configuration including:

- Authentication and registration settings
- Security policies (brute force protection, SSL)
- Session management (timeouts, lifespans)
- Internationalization support
- SMTP server configuration
- WebAuthn policies
- Custom attributes

#### Clients

Full OAuth 2.0/OpenID Connect client support:

- All access types (PUBLIC, CONFIDENTIAL, BEARER-ONLY)
- Flow configurations (standard, implicit, direct access)
- PKCE support for enhanced security
- URL validations (redirect, logout, origins)
- Token and session settings
- Consent management
- Protocol mappers
- Authorization services

#### Users

Complete user management:

- Basic profile information
- Password policies and initial passwords
- Custom attributes (multi-value support)
- Group memberships
- Role assignments (realm and client roles)
- Federated identity links
- Required actions
- Access permissions

#### Groups

Hierarchical group management:

- Parent-child relationships with validation
- Role assignments (realm and client)
- Custom attributes
- Default group settings
- Access permissions

#### Roles

Flexible role system:

- Realm and client roles
- Composite role support
- Role attributes
- Automatic dependency handling

#### Client Scopes

Advanced scope management:

- Protocol mappers
- Consent settings
- Token inclusion control
- Custom attributes

## Validation Features

The module includes comprehensive validation:

### Reference Validation

```bash
Invalid realm references found: non-existent-realm

Available realms: company, development

Make sure all referenced realms are defined in services.keycloak.realms.
```

### Circular Dependency Detection

```bash
Circular group dependencies detected: group-a, group-b

Group parent relationships must form a tree (no cycles).
Check the parentGroup settings in your group configurations.
```

### Uniqueness Validation

```bash
Duplicate client IDs found in realms: company

Client IDs must be unique within each realm.
```

### Security Validation

```bash
Public clients without PKCE found: mobile-app

In strict mode, public clients should use PKCE for security.
Set pkceCodeChallengeMethod = "S256" for these clients.
```

## Migration from Legacy Configuration

To migrate from the old `terranix-config.nix`:

1. **Update module import**: Change from importing `./terranix-config.nix` to using the new module
2. **Restructure configuration**: Move from flat `settings.terraform.*` to structured options
3. **Add type annotations**: Benefit from type checking and validation
4. **Enable validation**: Add cross-resource validation for better error detection

### Before (Legacy)

```nix
settings.terraform = {
  realms.company = {
    enabled = true;
    displayName = "Company";
  };
  clients.web-app = {
    realm = "company";
    accessType = "CONFIDENTIAL";
  };
};
```

### After (New Module)

```nix
services.keycloak = {
  enable = true;

  realms.company = {
    enabled = true;
    displayName = "Company";
  };

  clients.web-app = {
    realmId = "company";  # Type-safe reference
    accessType = "CONFIDENTIAL";
  };
};
```

## Best Practices

### 1. Use Type-Safe References

Always reference resources by their configuration keys:

```nix
clients.web-app = {
  realmId = "company";  # References realms.company
};

users.john = {
  realmId = "company";
  groups = [ "developers" ];  # References groups.developers
};
```

### 2. Enable Validation

Always enable cross-resource validation:

```nix
settings.validation = {
  enableCrossResourceValidation = true;
  strictMode = true;  # For production environments
};
```

### 3. Use Variables for Secrets

Never hardcode sensitive data:

```nix
variables = {
  admin_password = {
    description = "Keycloak admin password";
    sensitive = true;
  };
};

provider.password = "\${var.admin_password}";
```

### 4. Leverage Composite Roles

Use role composition for inheritance:

```nix
roles = {
  user = {
    description = "Basic user role";
  };

  developer = {
    description = "Developer with elevated permissions";
    compositeRoles.realmRoles = [ "user" ];
  };
};
```

### 5. Structure Groups Hierarchically

Organize groups in logical hierarchies:

```nix
groups = {
  employees = {
    defaultGroup = true;
    realmRoles = [ "user" ];
  };

  developers = {
    parentGroup = "employees";
    realmRoles = [ "developer" ];
  };

  senior-developers = {
    parentGroup = "developers";
    realmRoles = [ "senior-developer" ];
  };
};
```

## Troubleshooting

### Common Issues

1. **Reference Errors**: Use validation to catch missing resource references
2. **Circular Dependencies**: Check group parent relationships
3. **Duplicate Names**: Ensure unique names within each realm
4. **Type Errors**: Check option types and examples in module definitions

### Debug Mode

Enable verbose validation:

```nix
settings.validation = {
  enableCrossResourceValidation = true;
  strictMode = true;
};

outputs.validation_summary = {
  value = "\${local.keycloak_validation_summary}";
  description = "Validation summary for debugging";
};
```

## Contributing

When adding new features:

1. **Follow NixOS patterns**: Use proper module structure
2. **Add comprehensive types**: Include validation and examples
3. **Update validation**: Add cross-resource checks if needed
4. **Document thoroughly**: Include usage examples
5. **Test thoroughly**: Verify terraform generation works

## Examples

See `example.nix` for a complete, production-ready configuration demonstrating all features of the module architecture.