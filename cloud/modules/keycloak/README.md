# Keycloak Terranix Modules

This directory contains a comprehensive set of terranix modules for managing Keycloak infrastructure using OpenTofu/Terraform. The modules provide a declarative way to configure Keycloak realms, clients, users, groups, and roles.

## Module Structure

```
keycloak/
├── default.nix    # Main module entry point and provider configuration
├── realm.nix      # Realm management
├── clients.nix    # OIDC/OAuth2 client management
├── users.nix      # User, group, and role management
├── example.nix    # Example configuration
└── README.md      # This documentation
```

## Features

### Realm Management (`realm.nix`)
- Complete realm configuration including security settings
- Theme customization (login, admin, account, email)
- Token lifespan configuration
- Brute force protection settings
- Internationalization support
- Custom attributes

### Client Management (`clients.nix`)
- OpenID Connect client configuration
- Support for different access types (PUBLIC, CONFIDENTIAL, BEARER-ONLY)
- OAuth2 flow configuration (standard, implicit, direct access grants)
- Service account support
- PKCE configuration
- Client scope management
- Custom client attributes

### User, Group, and Role Management (`users.nix`)
- User creation and management
- Group hierarchy support
- Realm and client role definitions
- Role mappings for users and groups
- Custom attributes for users, groups, and roles
- Composite role support

## Usage

### 1. Import the Module

```nix
{
  imports = [
    ./cloud/modules/keycloak
  ];

  services.keycloak = {
    enable = true;
    url = "https://your-keycloak-instance.com";
    adminUser = "admin";
    adminPassword = "your-admin-password";
    # ... other configuration
  };
}
```

### 2. Basic Configuration

```nix
services.keycloak = {
  enable = true;
  url = "https://auth.company.com";
  adminUser = "admin";
  adminPassword = "admin-password";

  # Create a realm
  realms.my-realm = {
    name = "my-realm";
    displayName = "My Application Realm";
    enabled = true;
    registrationAllowed = true;
  };

  # Create a client
  clients.web-app = {
    name = "web-app";
    realmId = "my-realm";
    clientId = "web-application";
    accessType = "CONFIDENTIAL";
    validRedirectUris = [ "https://app.company.com/*" ];
  };
};
```

### 3. Complete Example

See `example.nix` for a comprehensive configuration that demonstrates:
- Multiple realms with different settings
- Various client types (web app, mobile app, API service)
- User and group management
- Role-based access control
- Client scope configuration

## Integration with Existing Infrastructure

This module is designed to work with the existing onix-core infrastructure:

1. **NixOS Keycloak Service**: Complements the NixOS Keycloak service running on aspen1
2. **Terranix Pattern**: Follows the same patterns as other terranix modules in the codebase
3. **Provider Configuration**: Automatically configures the Keycloak Terraform provider

## Configuration Options

### Provider Configuration
- `url`: Keycloak server URL
- `adminUser`: Admin username for authentication
- `adminPassword`: Admin password for authentication
- `clientId`: Client ID for provider authentication (default: "admin-cli")
- `clientTimeout`: Client timeout in seconds (default: 60)
- `initialLogin`: Whether to perform initial login (default: false)

### Realm Options
- Security settings (SSL requirements, brute force protection)
- User registration and email verification
- Theme customization
- Token lifespans
- Internationalization
- Custom attributes

### Client Options
- Access types (PUBLIC, CONFIDENTIAL, BEARER-ONLY)
- OAuth2 flows (authorization code, implicit, direct access grants)
- Service accounts
- Redirect URIs and web origins
- PKCE configuration
- Client scopes
- Custom attributes

### User/Group/Role Options
- User attributes and credentials
- Group hierarchies
- Role mappings (realm and client roles)
- Composite roles
- Custom attributes

## Best Practices

1. **Security**: Use variables or secrets for sensitive configuration like passwords
2. **Naming**: Use consistent naming conventions for resources
3. **Modularity**: Organize configuration by environment or application
4. **Dependencies**: Ensure proper resource dependencies (realms before clients, roles before mappings)
5. **Attributes**: Use custom attributes for application-specific metadata

## Development

The modules follow standard Nix module conventions:
- Options are defined using `mkOption` with proper types
- Configuration is applied conditionally using `mkIf cfg.enable`
- Resources are mapped from configuration using `mapAttrs'`
- Terraform resource names follow provider conventions

## Terraform Resources

The modules generate these Terraform resources:
- `keycloak_realm`
- `keycloak_openid_client`
- `keycloak_openid_client_scope`
- `keycloak_openid_client_default_scopes`
- `keycloak_openid_client_optional_scopes`
- `keycloak_user`
- `keycloak_group`
- `keycloak_role`
- `keycloak_user_groups`
- `keycloak_user_roles`
- `keycloak_group_roles`
- `keycloak_user_client_roles`
- `keycloak_group_client_roles`

## Integration with Cloud CLI

The modules are compatible with the cloud CLI commands for Keycloak resource management:
```bash
cloud keycloak create realm my-realm
cloud keycloak status client web-app
cloud keycloak destroy user john-doe
```