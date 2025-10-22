# Generic terranix configuration management system
# Abstracts configuration generation, change detection, and build-time vs runtime patterns
{ lib, pkgs, ... }:

let
  inherit (lib)
    types
    mkOption
    optionalAttrs
    mapAttrs
    mapAttrsToList
    foldl'
    recursiveUpdate
    ;

  # Terranix configuration type
  terranixConfigType = types.attrs;

  # Configuration options
  configOptions = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable terranix configuration generation";
    };

    configPath = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to terranix configuration file";
    };

    configAttr = mkOption {
      type = types.nullOr terranixConfigType;
      default = null;
      description = "Inline terranix configuration as Nix attribute set";
    };

    variables = mkOption {
      type = types.attrsOf (
        types.oneOf [
          types.str
          types.bool
          types.int
          types.float
        ]
      );
      default = { };
      description = "Terraform variables to pass to configuration";
      example = {
        admin_password = "secret123";
        enable_feature = true;
        port = 8080;
      };
    };

    providers = mkOption {
      type = types.attrsOf types.attrs;
      default = { };
      description = "Terraform providers configuration";
      example = {
        keycloak = {
          client_id = "admin-cli";
          username = "admin";
          password = "\${var.admin_password}";
          url = "http://localhost:8080";
        };
      };
    };

    buildTimeGeneration = mkOption {
      type = types.bool;
      default = true;
      description = "Generate configuration at build time (vs runtime)";
    };

    changeDetection = mkOption {
      type = types.bool;
      default = true;
      description = "Enable configuration change detection";
    };

    outputPath = mkOption {
      type = types.str;
      default = "main.tf.json";
      description = "Output filename for generated terraform configuration";
    };
  };

  # Generate terranix configuration JSON
  generateTerranixConfig =
    config: variables: providers:
    let
      # Base configuration structure
      baseConfig = {
        terraform = {
          required_version = ">= 1.0.0";
          required_providers = mapAttrs (name: providerConfig: {
            source = providerConfig.source or "registry.opentofu.org/${name}";
            version = providerConfig.version or "~> 1.0";
          }) providers;
        };

        # Variable definitions
        variable = mapAttrs (name: value: {
          type =
            if builtins.isBool value then
              "bool"
            else if builtins.isInt value || builtins.isFloat value then
              "number"
            else
              "string";
          description = "Variable ${name}";
          sensitive =
            if name == "password" || lib.hasSuffix "_password" name || lib.hasSuffix "_secret" name then
              true
            else
              false;
        }) variables;

        # Provider configurations
        provider = providers;
      };

      # Merge with user configuration
      finalConfig = if config != null then recursiveUpdate baseConfig config else baseConfig;
    in
    finalConfig;

  # Generate configuration change detection script
  generateChangeDetectionScript = serviceName: instanceName: configPath: ''
    # Configuration change detection
    mkdir -p /var/lib/${serviceName}-${instanceName}-terraform

    CURRENT_CONFIG_HASH=$(sha256sum ${configPath} | cut -d' ' -f1)
    LAST_DEPLOY_HASH=$(cat /var/lib/${serviceName}-${instanceName}-terraform/.last-deploy-hash 2>/dev/null || echo "")

    if [ "$CURRENT_CONFIG_HASH" != "$LAST_DEPLOY_HASH" ]; then
      echo "Terraform configuration changed (${serviceName}-${instanceName})"
      rm -f /var/lib/${serviceName}-${instanceName}-terraform/.deploy-complete
      touch /var/lib/${serviceName}-${instanceName}-terraform/.needs-apply
      return 0  # Configuration changed
    else
      echo "Terraform configuration unchanged (${serviceName}-${instanceName})"
      return 1  # Configuration unchanged
    fi
  '';

  # Generate terraform variables file script
  generateTerraformVarsScript = variables: credentialFiles: ''
    # Generate terraform.tfvars file
    cat > terraform.tfvars <<'EOF'
    ${lib.concatStringsSep "\n" (
      mapAttrsToList (
        name: value:
        if builtins.isString value then
          if lib.hasPrefix "$CREDENTIALS_DIRECTORY/" value then
            # This is a credential file reference
            ''${name} = "$(cat ${value})"''
          else
            # Regular string value
            ''${name} = "${value}"''
        else if builtins.isBool value then
          ''${name} = ${if value then "true" else "false"}''
        else if builtins.isInt value || builtins.isFloat value then
          ''${name} = ${toString value}''
        else
          ''${name} = "${toString value}"''
      ) variables
    )}
    EOF

    # Process credential files
    ${lib.concatStringsSep "\n" (
      map (credFile: ''
        if [ -f "${credFile.source}" ]; then
          echo '${credFile.name} = "'$(cat ${credFile.source})'"' >> terraform.tfvars
        fi
      '') credentialFiles
    )}
  '';

  # Build-time configuration generator
  buildTimeConfigGenerator =
    {
      config,
      variables,
      providers,
      outputPath,
    }:
    pkgs.writeText outputPath (builtins.toJSON (generateTerranixConfig config variables providers));

  # Runtime configuration generator script
  runtimeConfigGenerator =
    {
      config,
      variables,
      providers,
      outputPath,
    }:
    ''
      # Generate terraform configuration at runtime
      cat > ${outputPath} <<'EOF'
      ${builtins.toJSON (generateTerranixConfig config variables providers)}
      EOF
      echo "Generated runtime terraform configuration: ${outputPath}"
    '';

  # Terranix integration helpers
  terranixHelpers = {
    # Common resource generators
    realm = name: config: {
      keycloak_realm.${name} = lib.filterAttrs (_: v: v != null) (
        config
        // {
          realm = name;
          enabled = config.enabled or true;
        }
      );
    };

    client = name: config: {
      keycloak_openid_client.${name} = lib.filterAttrs (_: v: v != null) (
        config
        // {
          client_id = name;
          realm_id = "\${keycloak_realm.${config.realm}.id}";
        }
      );
    };

    user = name: config: {
      keycloak_user.${name} = lib.filterAttrs (_: v: v != null) (
        config
        // {
          username = name;
          realm_id = "\${keycloak_realm.${config.realm}.id}";
        }
      );
    };

    group = name: config: {
      keycloak_group.${name} = lib.filterAttrs (_: v: v != null) (
        config
        // {
          inherit name;
          realm_id = "\${keycloak_realm.${config.realm}.id}";
        }
      );
    };

    role = name: config: {
      keycloak_role.${name} = lib.filterAttrs (_: v: v != null) (
        config
        // {
          inherit name;
          realm_id = "\${keycloak_realm.${config.realm}.id}";
        }
        // optionalAttrs (config.client or null != null) {
          client_id = "\${keycloak_openid_client.${config.client}.id}";
        }
      );
    };

    # Generic resource generator
    resource = type: name: config: {
      ${type}.${name} = config;
    };

    # Merge multiple resource configurations
    mergeResources = resources: foldl' recursiveUpdate { } resources;

    # Generate outputs for created resources
    generateOutputs = resources: {
      output = mapAttrs (
        type: typeResources:
        mapAttrs (name: _: {
          value = "\${${type}.${name}.id}";
          description = "ID of ${type} ${name}";
        }) typeResources
      ) resources;
    };
  };

in
{
  # Main terranix configuration management function
  generateTerranixSystem =
    {
      serviceName,
      instanceName,
      config ? null,
      configPath ? null,
      variables ? { },
      providers ? { },
      credentialFiles ? [ ],
      buildTimeGeneration ? true,
      changeDetection ? true,
      outputPath ? "main.tf.json",
    }:
    let
      # Determine configuration source
      terraformConfig =
        if configPath != null then
          import configPath {
            inherit lib;
            settings = { inherit variables providers; };
          }
        else if config != null then
          config
        else
          throw "Either config or configPath must be provided";

      # Generate configuration file
      configFile =
        if buildTimeGeneration then
          buildTimeConfigGenerator {
            config = terraformConfig;
            inherit variables providers outputPath;
          }
        else
          null;

      # Generate configuration scripts
      changeDetectionScript =
        if changeDetection then
          generateChangeDetectionScript serviceName instanceName (
            if configFile != null then configFile else configPath
          )
        else
          "";

      varsScript = generateTerraformVarsScript variables credentialFiles;

      runtimeConfigScript =
        if not buildTimeGeneration then
          runtimeConfigGenerator {
            config = terraformConfig;
            inherit variables providers outputPath;
          }
        else
          "";

    in
    {
      # Generated configuration file (for build-time generation)
      configFile = configFile;

      # Configuration generation script (for runtime generation)
      configScript = runtimeConfigScript;

      # Variables generation script
      varsScript = varsScript;

      # Change detection script
      changeDetectionScript = changeDetectionScript;

      # Activation script for NixOS
      activationScript = lib.mkIf changeDetection {
        text = changeDetectionScript;
        deps = [ "setupSecrets" ];
      };

      # Helper functions
      helpers = terranixHelpers;

      # Configuration validation
      validateConfig = {
        hasConfig = config != null || configPath != null;
        hasProviders = providers != { };
        buildTimeReady = buildTimeGeneration && configFile != null;
        runtimeReady = not buildTimeGeneration && runtimeConfigScript != "";
      };
    };

  # Option types for external use
  options = {
    terranix = configOptions;
  };

  # Helper utilities
  helpers = terranixHelpers;

  # Type definitions
  types = {
    terranixConfig = terranixConfigType;
  };
}
