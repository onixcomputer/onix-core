# OpenTofu Credential Integration Library

This library provides secure integration between clan vars and OpenTofu/Terraform by automating the generation of systemd LoadCredential entries and terraform.tfvars.

## Key Features

- **Secure Credential Bridging**: Automatically maps clan vars to terraform variables
- **Systemd Integration**: Generates proper LoadCredential configurations
- **Flexible Mapping**: Supports both simple string mappings and advanced configurations
- **Validation**: Ensures all required clan vars generators and files exist

## Usage

### Basic Example

```nix
{
  # Import the library
  imports = [ ./modules/lib/opentofu ];

  # Configure credential mapping
  opentofu.credentialMapping = {
    "database_password" = "db_password";        # Simple mapping
    "admin_token" = "admin_token";
    "api_key" = "api_secret";
  };

  # In your systemd service
  systemd.services.my-terraform-service = {
    serviceConfig = {
      LoadCredential = config._lib.opentofu.generateLoadCredentials "my-service" config.opentofu.credentialMapping;
    };

    script = ''
      ${config._lib.opentofu.generateTfvarsScript config.opentofu.credentialMapping ""}

      # Now terraform.tfvars contains:
      # database_password = "$(cat $CREDENTIALS_DIRECTORY/db_password)"
      # admin_token = "$(cat $CREDENTIALS_DIRECTORY/admin_token)"
      # api_key = "$(cat $CREDENTIALS_DIRECTORY/api_secret)"

      tofu init
      tofu apply -var-file=terraform.tfvars
    '';
  };
}
```

### Advanced Example

```nix
{
  opentofu.credentialMapping = {
    "database_password" = {
      clanVarFile = "db_password";
      generatorName = "my-service";
      optional = false;
    };
    "admin_token" = {
      clanVarFile = "admin_token";
      generatorName = "shared-auth";  # Different generator
      optional = false;
    };
  };

  opentofu.additionalCredentials = [
    "custom_secret:/path/to/external/secret"
  ];

  opentofu.tfvarsTemplate = ''
    # Additional static variables
    environment = "production"
    region = "us-west-2"
  '';
}
```

## Library Functions

### `generateLoadCredentials instanceName credentialMapping`

Generates systemd LoadCredential entries from the credential mapping.

**Parameters:**
- `instanceName`: Service instance name (used as default generator name)
- `credentialMapping`: Attribute set mapping terraform vars to clan vars

**Returns:** List of LoadCredential strings

### `generateTfvarsContent credentialMapping additionalContent`

Generates terraform.tfvars content from credential mapping.

**Parameters:**
- `credentialMapping`: Credential mapping configuration
- `additionalContent`: Additional static tfvars content

**Returns:** String containing tfvars content

### `generateTfvarsScript credentialMapping additionalContent`

Generates a shell script that creates terraform.tfvars from credentials.

### `validateCredentialMapping instanceName credentialMapping`

Validates that all required clan vars generators and files exist.

**Returns:** Attribute set with validation results

## Integration Pattern

This library extracts the pattern used in the keycloak module:

1. **Clan vars generators** define the secrets
2. **LoadCredential** maps clan vars files to systemd credentials
3. **terraform.tfvars** reads from `$CREDENTIALS_DIRECTORY`
4. **Services** use the generated terraform.tfvars

The library automates steps 2-3, making secure terraform authentication standardized across all services.