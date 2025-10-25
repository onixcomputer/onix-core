# OpenTofu Library Architecture

The OpenTofu library follows a **layered architecture** that provides multiple levels of abstraction, allowing users to choose the right level of control for their use case.

## Overview

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: High-Level Composite Functions                    │
│ • mkTerranixService (recommended for most users)           │
│ • mkTerranixDeployment                                      │
│ • mkTerranixInfrastructure                                  │
├─────────────────────────────────────────────────────────────┤
│ Layer 2: Modular Functions                                 │
│ • systemd: mkTerranixInfrastructure, mkTerranixActivation  │
│ • terranix: generateTerranixJson, evalTerranixModule       │
│ • backends: mkBackend, mkS3Backend, mkLocalBackend         │
├─────────────────────────────────────────────────────────────┤
│ Layer 1: Pure Functions                                    │
│ • credentials: generateLoadCredentials                     │
│ • paths: makeServiceName, makeStateDirectory               │
│ • validation: validateTerranixConfig                       │
│ • utilities: extractVariables, extractResources            │
└─────────────────────────────────────────────────────────────┘
```

## Layer 3: High-Level Composite Functions

**🎯 Recommended for most users**

These functions create complete NixOS configurations with all necessary components:

### `mkTerranixService`

The primary high-level interface that creates:
- SystemD deployment service
- SystemD activation script
- Helper scripts (unlock, status, apply, logs)
- Backend initialization (S3/Garage if needed)
- Proper dependencies and ordering

```nix
opentofu.mkTerranixService {
  serviceName = "postgres";
  instanceName = "production";
  terranixModule = ./postgres-config.nix;
  credentialMapping = { admin_password = "postgres_password"; };
  backendType = "s3";
  generateHelperScripts = true;
}
# Returns: Complete NixOS configuration
```

### `mkTerranixDeployment`

Simplified wrapper for common deployment scenarios:

```nix
opentofu.mkTerranixDeployment {
  serviceName = "redis";
  instanceName = "cache";
  terranixModule = ./redis-config.nix;
  credentialMapping = { };
}
```

### When to Use Layer 3

- ✅ You want a complete working service with minimal configuration
- ✅ You're new to the library
- ✅ You want sensible defaults with customization options
- ✅ You need systemd services + activation + helper scripts

## Layer 2: Modular Functions

**🔧 For advanced users who want control**

These functions let you compose exactly what you need:

### SystemD Module (`systemd/`)

```nix
# Create deployment service only
deployment = opentofu.mkTerranixInfrastructure { ... };

# Create activation script only
activation = opentofu.mkTerranixActivation { ... };

# Create helper scripts only
helpers = opentofu.mkTerranixScripts { ... };
```

### Terranix Module (`terranix/`)

```nix
# Generate JSON from terranix module
config = opentofu.generateTerranixJson {
  module = ./my-config.nix;
};

# Evaluate terranix module
evaluated = opentofu.evalTerranixModule {
  module = ./my-config.nix;
};

# Test terranix module
tests = opentofu.testTerranixModule {
  module = ./my-config.nix;
  testCases = { ... };
};
```

### Backends Module (`backends/`)

```nix
# Create S3 backend
s3Backend = opentofu.mkS3Backend {
  serviceName = "app";
  instanceName = "prod";
};

# Auto-detect best backend
backend = opentofu.autoDetectBackend {
  requiresSharedState = true;
  hasGarageService = true;
};
```

### When to Use Layer 2

- ✅ You need custom composition of components
- ✅ You're building complex deployment workflows
- ✅ You want to exclude certain components (e.g., no helper scripts)
- ✅ You're integrating with existing infrastructure

## Layer 1: Pure Functions

**⚙️ For library authors and power users**

These are the building blocks used by higher layers:

### Credentials (`pure/credentials.nix`)

```nix
# Generate systemd LoadCredential entries
creds = opentofu.generateLoadCredentials "myservice" {
  db_password = "database_password";
  api_key = "service_api_key";
};
# Result: ["db_password:/run/secrets/vars/myservice/database_password", ...]
```

### Paths (`pure/paths.nix`)

```nix
# Generate consistent paths and names
serviceName = opentofu.makeServiceName "postgres" "prod";           # "postgres-prod"
stateDir = opentofu.makeStateDirectory "postgres" "prod";           # "/var/lib/postgres-prod-terraform"
unlockScript = opentofu.makeUnlockScriptName "postgres" "prod";     # "postgres-tf-unlock-prod"
```

### Validation (`pure/validation.nix`)

```nix
# Validate terranix configurations
validated = opentofu.validateTerranixConfig myConfig;

# Generate configuration IDs
configId = opentofu.generateConfigId myConfig;

# Merge multiple configurations
merged = opentofu.mergeConfigurations [config1 config2];
```

### Utilities (`pure/utilities.nix`)

```nix
# Extract information from configurations
variables = opentofu.extractVariables config;      # ["var1", "var2"]
resources = opentofu.extractResources config;      # [{ type = "null_resource"; name = "test"; }]
components = opentofu.extractServiceComponents "postgres" "prod";  # { stateDir = ...; lockFile = ...; }
```

### When to Use Layer 1

- ✅ You're building custom higher-level abstractions
- ✅ You need maximum flexibility and control
- ✅ You're creating domain-specific deployment tools
- ✅ You want fast testing with nix-unit

## Directory Structure

```
lib/opentofu/
├── default.nix              # Main entry point (imports all layers)
├── pure/                    # Layer 1: Pure functions
│   ├── credentials.nix      # Credential management utilities
│   ├── paths.nix           # Path and name generation
│   ├── validation.nix      # Configuration validation
│   ├── utilities.nix       # Analysis and debugging utilities
│   ├── backends.nix        # Backend configuration generation
│   └── default.nix         # Pure function entry point
├── systemd/                 # Layer 2: SystemD integration
│   ├── health-checks.nix   # Health check strategies
│   ├── deployment.nix      # Deployment service generation
│   ├── scripts.nix        # Helper script generation
│   ├── garage.nix         # Garage S3 initialization
│   ├── activation.nix     # Activation script management
│   └── default.nix        # SystemD module entry point
├── terranix/               # Layer 2: Terranix integration
│   ├── eval.nix           # Module evaluation
│   ├── validation.nix     # Configuration validation
│   ├── generation.nix     # JSON generation
│   ├── testing.nix        # Testing utilities
│   ├── utilities.nix      # Helper utilities
│   ├── types.nix          # Type definitions
│   └── default.nix        # Terranix module entry point
├── backends/               # Layer 2: Backend configuration
│   ├── local.nix          # Local filesystem backend
│   ├── s3.nix             # S3/Garage backend
│   └── default.nix        # Unified backend interface
├── tests/                  # Comprehensive testing
│   ├── unit/              # nix-unit tests for pure functions
│   └── integration/       # Cross-module integration tests
└── examples/              # Usage examples
    ├── quick-start.nix    # Layered architecture examples
    └── simple-terranix-example.nix  # Basic usage
```

## Design Principles

### 1. **Composability**
Each function can be used independently or combined with others. Higher layers are built by composing lower layers.

### 2. **Separation of Concerns**
- **Pure functions**: No side effects, fast evaluation, nix-unit testable
- **Modular functions**: Single responsibility, focused domains
- **Composite functions**: Convenient combinations for common use cases

### 3. **Flexibility**
Users can choose their level of abstraction:
- **Simple users**: Use Layer 3 composite functions
- **Advanced users**: Compose Layer 2 modular functions
- **Power users**: Build custom abstractions with Layer 1 pure functions

### 4. **Backward Compatibility**
All existing APIs are preserved. New layers are additive, not breaking.

### 5. **Testability**
- Layer 1: Fast nix-unit tests (no derivations)
- Layer 2: Integration tests (with derivations)
- Layer 3: System tests (full NixOS VM)

## Usage Patterns

### Pattern 1: Simple Service Deployment

```nix
# One function call creates everything needed
postgres = opentofu.mkTerranixService {
  serviceName = "postgres";
  instanceName = "prod";
  terranixModule = ./postgres.nix;
  credentialMapping = { admin_password = "postgres_password"; };
};
```

### Pattern 2: Custom Composition

```nix
# Build exactly what you need
let
  config = opentofu.generateTerranixJson { module = ./my-config.nix; };
  deployment = opentofu.mkTerranixInfrastructure {
    terraformConfigPath = config;
    # custom options
  };
  # Skip activation scripts, add custom backend
  backend = opentofu.mkS3Backend { /* custom S3 config */ };
in deployment // backend
```

### Pattern 3: Multi-Environment

```nix
# Generate services for multiple environments
environments = lib.genAttrs ["dev" "staging" "prod"] (env:
  opentofu.mkTerranixService {
    serviceName = "app";
    instanceName = env;
    terranixModule = ./app-config.nix;
    terranixModuleArgs = { environment = env; };
    backendType = if env == "prod" then "s3" else "local";
  }
);
```

### Pattern 4: Migration Path

```nix
# Stage 1: Use existing JSON
legacy = opentofu.mkTerranixInfrastructure {
  terraformConfigPath = ./legacy-config.json;
};

# Stage 2: Convert to terranix
terranix = opentofu.mkTerranixInfrastructure {
  terranixModule = ./converted-config.nix;
};

# Stage 3: Full integration
complete = opentofu.mkTerranixService {
  terranixModule = ./converted-config.nix;
  # All features enabled
};
```

## Performance Characteristics

| Layer | Evaluation Speed | Flexibility | Ease of Use |
|-------|------------------|-------------|-------------|
| Layer 1 (Pure) | ⚡ Very Fast | 🔧 Maximum | 🎓 Expert |
| Layer 2 (Modular) | ⚡ Fast | 🔧 High | 🎓 Advanced |
| Layer 3 (Composite) | 🐌 Slower | 🔧 Medium | 🎯 Easy |

- **Layer 1**: nix-unit testable, no derivations, instant evaluation
- **Layer 2**: Some derivations (JSON generation), moderate evaluation time
- **Layer 3**: Full derivations (services + scripts), complete but slower

## Migration Guide

### From Existing OpenTofu Usage

1. **Currently using `mkTerranixInfrastructure`**:
   - ✅ Keep using it (no changes needed)
   - 🚀 Consider upgrading to `mkTerranixService` for additional features

2. **Currently using multiple separate function calls**:
   - 🚀 Consider `mkTerranixService` to reduce boilerplate
   - 🔧 Or continue with modular approach if you need custom composition

3. **Building custom infrastructure tools**:
   - 🔧 Use Layer 1 pure functions as building blocks
   - 📚 Study existing Layer 2 and 3 implementations for patterns

### From JSON Terraform Configs

1. **Start with `mkTerranixInfrastructure`** and existing JSON
2. **Convert to terranix modules** when ready
3. **Upgrade to `mkTerranixService`** for full integration

This layered architecture provides a clear path from simple usage to advanced customization while maintaining excellent composability and testability.