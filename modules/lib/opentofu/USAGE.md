# OpenTofu Backend Library Usage Guide

This library provides a comprehensive, generic backend management system for OpenTofu/Terraform integration in clan services. It abstracts all the complexity of Garage S3 backend setup, credential management, and configuration change detection into reusable components.

## Quick Start

### 1. Import the Library

```nix
{
  imports = [ ./modules/lib/opentofu ];

  # Access via config._lib.opentofu
  opentofuSystem = config._lib.opentofu.generateOpenTofuService {
    serviceName = "my-service";
    instanceName = "main";
    backend.type = "garage";
    autoApply = true;
  };
}
```

### 2. Basic Garage Backend Usage

```nix
# Simple Garage backend with automatic clan vars integration
backend = config._lib.opentofu.service.backends.garageWithClanVars {
  bucket = "terraform-state";
  keyPrefix = "my-service";
};

# Use in service
opentofuSystem = config._lib.opentofu.generateOpenTofuService {
  serviceName = "my-service";
  instanceName = "main";
  inherit backend;
  autoApply = true;

  terranix = {
    resource.null_resource.example = {
      provisioner.local-exec.command = "echo 'Hello World'";
    };
  };
};
```

### 3. Complete Service Integration

```nix
# Full example with all features
opentofuSystem = config._lib.opentofu.generateOpenTofuService {
  serviceName = "keycloak";
  instanceName = "main";

  # Backend configuration
  backend = {
    type = "garage";
    bucket = "terraform-state";
    keyPrefix = "keycloak";
    garageCredentials.autoDetectClanVars = true;
  };

  # Automatic deployment
  autoApply = true;

  # Service dependencies
  dependsOn = [ "postgresql.service" ];
  waitForService = "keycloak.service";

  # Credentials from clan vars
  credentialFiles = [{
    name = "admin_password";
    source = config.clan.core.vars.generators.keycloak.files.admin_password.path;
  }];

  # Terraform variables
  variables = {
    admin_password = "$CREDENTIALS_DIRECTORY/admin_password";
  };

  # Provider configuration
  providers = {
    keycloak = {
      source = "registry.opentofu.org/mrparkers/keycloak";
      version = "~> 4.4";
      url = "http://localhost:8080";
    };
  };

  # Terraform resources
  terranix = {
    resource = {
      keycloak_realm.company = {
        realm = "company";
        enabled = true;
      };
    };
  };
};
```

## Backend Types

### Local Backend (Default)

```nix
backend = { type = "local"; };
```

### Garage Backend

```nix
# Auto-detect clan vars credentials
backend = config._lib.opentofu.service.backends.garageWithClanVars {
  bucket = "terraform-state";
  keyPrefix = "my-service";
};

# Or explicit configuration
backend = {
  type = "garage";
  bucket = "terraform-state";
  endpoint = "http://127.0.0.1:3900";
  region = "garage";
  keyPrefix = "my-service";
  garageCredentials = {
    adminTokenFile = "/path/to/admin/token";
    rpcSecretFile = "/path/to/rpc/secret";
  };
};
```

### S3 Backend

```nix
backend = {
  type = "s3";
  bucket = "my-terraform-state";
  endpoint = "https://s3.amazonaws.com";
  region = "us-east-1";
  s3Credentials = {
    accessKeyFile = "/path/to/access/key";
    secretKeyFile = "/path/to/secret/key";
  };
};
```

## What the Library Provides

### Automatic Infrastructure

1. **Garage Bucket Creation**: Automatically creates buckets and access keys
2. **Credential Management**: Secure credential loading via systemd
3. **Service Dependencies**: Proper service ordering and dependencies
4. **Configuration Change Detection**: Automatic re-deployment on config changes
5. **Helper Commands**: Status, unlock, and management scripts

### Generated Services

- `garage-terraform-init-${instanceName}`: Bucket and credential setup
- `${serviceName}-terraform-deploy-${instanceName}`: Synchronous deployment
- Helper commands: `${serviceName}-tf-status-${instanceName}`, etc.

### Benefits Over Manual Implementation

- **700+ lines of code replaced** with simple declarative configuration
- **Consistent patterns** across all clan services
- **Automatic backend detection** and setup
- **Built-in error handling** and validation
- **Zero custom implementation** required for sophisticated backends

## Integration Pattern

### Before (Manual Garage Integration)

```nix
# 255 lines of garage-terraform-init service
# 180 lines of terraform deployment services
# 100 lines of backend configuration generation
# 80 lines of credential loading scripts
# 50 lines of helper command scripts
# 30 lines of state locking implementation
# Complex activation scripts for change detection
```

### After (Library Integration)

```nix
opentofuSystem = config._lib.opentofu.generateOpenTofuService {
  serviceName = "my-service";
  instanceName = "main";
  backend.type = "garage";
  autoApply = true;
  terranix = { /* terraform config */ };
};
```

## Advanced Usage

### Garage Deployment Pattern

For services that need the full Garage deployment pattern:

```nix
garageDeployment = config._lib.opentofu.mkGarageDeployment {
  serviceName = "my-service";
  instanceName = "main";
  terraformConfigPath = ./my-terraform.json;
  garageConfig = {
    bucket = "terraform-state";
    credentialsConfig.autoDetectClanVars = true;
  };
  dependencies = [ "my-service.service" ];
};
```

### Custom Patterns

The library is designed to be extensible for custom use cases:

```nix
customPattern = config._lib.opentofu.service.patterns.httpService {
  instanceName = "main";
  serviceName = "my-api";
  serviceUrl = "http://localhost:8080/health";
  backend = config._lib.opentofu.service.backends.garageWithClanVars {};
};
```

## Migration from Keycloak Pattern

To migrate existing services using the keycloak Garage pattern:

1. Replace garage-terraform-init service with `backend.type = "garage"`
2. Replace manual credential loading with `credentialFiles` configuration
3. Replace custom deployment services with `autoApply = true`
4. Use `terranix` configuration instead of separate terraform files

The library handles all the complexity automatically while providing the same functionality.