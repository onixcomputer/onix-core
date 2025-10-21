# Keycloak Terranix Module
# Main module following NixOS-style patterns with proper options, config, and imports
{ config, lib, ... }:

let
  inherit (lib)
    mkOption
    mkEnableOption
    mkIf
    types
    mkDefault
    mkMerge
    ;

  cfg = config.services.keycloak;

  # Base types for validation
  keycloakBaseTypes = {
    # Non-empty string type
    nonEmptyStr = types.strMatching ".+" // {
      description = "non-empty string";
    };

    # URL type with validation
    url = types.strMatching "https?://.*" // {
      description = "HTTP or HTTPS URL";
    };

    # Duration string type (e.g., "30m", "1h", "24h")
    duration = types.strMatching "[0-9]+[smhd]" // {
      description = "duration string (e.g., '30m', '1h', '24h')";
    };

    # Password policy string
    passwordPolicy = types.nullOr (types.strMatching ".*") // {
      description = "Keycloak password policy string";
    };

    # Theme name
    themeName =
      types.nullOr (
        types.enum [
          "base"
          "keycloak"
        ]
      )
      // {
        description = "Keycloak theme name";
      };

    # SSL requirement level
    sslRequired = types.enum [
      "external"
      "none"
      "all"
    ];

    # Access type for clients
    accessType = types.enum [
      "PUBLIC"
      "CONFIDENTIAL"
      "BEARER-ONLY"
    ];

    # PKCE code challenge method
    pkceMethod = types.nullOr (
      types.enum [
        "S256"
        "plain"
      ]
    );

    # User attributes (key-value pairs where values are lists)
    userAttributes = types.attrsOf (types.listOf types.str);

    # Role attributes
    roleAttributes = types.attrsOf types.str;

    # Group attributes
    groupAttributes = types.attrsOf (types.listOf types.str);
  };

  # Resource reference types for dependencies
  resourceRefTypes = {
    realmRef = types.str // {
      description = "Reference to a realm (realm name)";
    };

    clientRef = types.str // {
      description = "Reference to a client (client resource name)";
    };

    userRef = types.str // {
      description = "Reference to a user (user resource name)";
    };

    groupRef = types.str // {
      description = "Reference to a group (group resource name)";
    };

    roleRef = types.str // {
      description = "Reference to a role (role resource name)";
    };
  };

in
{
  imports = [
    ./provider.nix # Provider configuration
    ./realms.nix # Realm management
    ./clients.nix # Client management
    ./users.nix # User management
    ./groups.nix # Group management
    ./roles.nix # Role management
    ./client-scopes.nix # Client scope management
    ./validation.nix # Cross-resource validation
  ];

  options.services.keycloak = {
    enable = mkEnableOption "Keycloak Terraform resources" // {
      description = ''
        Enable Keycloak Terraform resource management.
        This will configure the Keycloak provider and enable
        declarative management of realms, clients, users, groups, and roles.
      '';
    };

    # Provider configuration options
    provider = {
      url = mkOption {
        type = keycloakBaseTypes.url;
        description = "Keycloak server URL";
        example = "https://auth.example.com";
      };

      realm = mkOption {
        type = keycloakBaseTypes.nonEmptyStr;
        default = "master";
        description = "Admin realm for provider authentication";
      };

      username = mkOption {
        type = keycloakBaseTypes.nonEmptyStr;
        default = "admin";
        description = "Admin username for provider authentication";
      };

      password = mkOption {
        type = types.str;
        description = ''
          Admin password for provider authentication.
          In production, this should reference a variable.
        '';
        example = "\${var.keycloak_admin_password}";
      };

      clientId = mkOption {
        type = keycloakBaseTypes.nonEmptyStr;
        default = "admin-cli";
        description = "Client ID for provider authentication";
      };

      clientTimeout = mkOption {
        type = types.ints.positive;
        default = 60;
        description = "Client timeout in seconds";
      };

      initialLogin = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to perform initial login";
      };

      tlsInsecureSkipVerify = mkOption {
        type = types.bool;
        default = false;
        description = "Skip TLS certificate verification (not recommended for production)";
      };

      additionalHeaders = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Additional HTTP headers to send with requests";
      };
    };

    # Global settings that affect all resources
    settings = {
      # Default realm for resources that don't specify one
      defaultRealm = mkOption {
        type = types.nullOr resourceRefTypes.realmRef;
        default = null;
        description = ''
          Default realm to use for resources that don't specify a realm.
          If not set, realm must be specified for each resource.
        '';
      };

      # Resource naming strategy
      resourcePrefix = mkOption {
        type = types.str;
        default = "";
        description = ''
          Prefix to add to all terraform resource names.
          Useful for avoiding conflicts in multi-environment setups.
        '';
      };

      # Validation settings
      validation = {
        enableCrossResourceValidation = mkOption {
          type = types.bool;
          default = true;
          description = "Enable validation of cross-resource references";
        };

        strictMode = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Enable strict validation mode. This will fail on warnings
            and enforce stricter validation rules.
          '';
        };
      };
    };

    # Variables for sensitive data
    variables = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            description = mkOption {
              type = types.str;
              description = "Variable description";
            };

            type = mkOption {
              type = types.str;
              default = "string";
              description = "Variable type";
            };

            sensitive = mkOption {
              type = types.bool;
              default = false;
              description = "Whether this variable contains sensitive data";
            };

            default = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Default value for the variable";
            };
          };
        }
      );
      default = { };
      description = ''
        Terraform variables to declare.
        These can be referenced in resource configurations using \${var.variable_name}.
      '';
      example = {
        admin_password = {
          description = "Keycloak admin password";
          type = "string";
          sensitive = true;
        };
        client_secret = {
          description = "OAuth client secret";
          type = "string";
          sensitive = true;
        };
      };
    };

    # Outputs to expose from terraform
    outputs = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            value = mkOption {
              type = types.str;
              description = "Output value expression";
            };

            description = mkOption {
              type = types.str;
              description = "Output description";
            };

            sensitive = mkOption {
              type = types.bool;
              default = false;
              description = "Whether this output contains sensitive data";
            };
          };
        }
      );
      default = { };
      description = ''
        Terraform outputs to expose.
        These allow accessing resource attributes after deployment.
      '';
      example = {
        realm_id = {
          value = "\${keycloak_realm.main.id}";
          description = "Main realm ID";
        };
        client_secret = {
          value = "\${keycloak_openid_client.app.client_secret}";
          description = "Application client secret";
          sensitive = true;
        };
      };
    };
  };

  config = mkIf cfg.enable {
    # Set up Terraform configuration
    terraform = {
      required_version = mkDefault ">= 1.0";

      required_providers.keycloak = {
        source = "registry.opentofu.org/mrparkers/keycloak";
        version = "~> 4.4";
      };
    };

    # Declare variables
    variable = cfg.variables;

    # Configure outputs
    output = cfg.outputs;

    # Add default variables if not explicitly defined
    variable = mkMerge [
      # Default admin password variable if not already defined
      (mkIf (!cfg.variables ? keycloak_admin_password) {
        keycloak_admin_password = {
          description = "Keycloak admin password for provider authentication";
          type = "string";
          sensitive = true;
        };
      })
    ];

    # Add default outputs for commonly needed values
    output = mkMerge [
      # Add summary outputs if any resources are defined
      (mkIf
        (
          cfg.realms != { } || cfg.clients != { } || cfg.users != { } || cfg.groups != { } || cfg.roles != { }
        )
        {
          keycloak_summary = {
            value = builtins.toJSON {
              realms = lib.attrNames cfg.realms;
              clients = lib.attrNames cfg.clients;
              users = lib.attrNames cfg.users;
              groups = lib.attrNames cfg.groups;
              roles = lib.attrNames cfg.roles;
            };
            description = "Summary of managed Keycloak resources";
          };
        }
      )
    ];

    # Add terraform formatting annotations
    _meta.terraform = {
      formatVersion = "1.0";
      generatedBy = "terranix-keycloak-module";
      generatedAt = builtins.currentTime;
    };
  };
}
