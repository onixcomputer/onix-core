# Terranix Type Definitions
{ lib }:

let
  inherit (lib) mkOption types;
in
{
  # Type for terranix modules - can be path, function, or attribute set
  terranixModuleType = types.either types.path (types.functionTo types.attrs);

  # Type for terranix configuration structure
  terranixConfigType = types.submodule {
    options = {
      terraform = mkOption {
        type = types.nullOr types.attrs;
        default = null;
        description = "Terraform configuration block";
      };

      provider = mkOption {
        type = types.nullOr types.attrs;
        default = null;
        description = "Provider configurations";
      };

      variable = mkOption {
        type = types.nullOr types.attrs;
        default = null;
        description = "Variable definitions";
      };

      resource = mkOption {
        type = types.nullOr types.attrs;
        default = null;
        description = "Resource definitions";
      };

      output = mkOption {
        type = types.nullOr types.attrs;
        default = null;
        description = "Output definitions";
      };
    };
  };

  # Type for module arguments
  moduleArgsType = types.attrs;

  # Type for evaluation options
  evalOptionsType = types.submodule {
    options = {
      debug = mkOption {
        type = types.bool;
        default = false;
        description = "Enable debug mode with source information";
      };

      validate = mkOption {
        type = types.bool;
        default = true;
        description = "Enable validation mode with strict type checking";
      };
    };
  };

  # Type for generation options
  generationOptionsType = types.submodule {
    options = {
      fileName = mkOption {
        type = types.str;
        default = "terraform.json";
        description = "Output file name";
      };

      prettyPrintJson = mkOption {
        type = types.bool;
        default = false;
        description = "Pretty print JSON output";
      };

      validate = mkOption {
        type = types.bool;
        default = true;
        description = "Enable validation during generation";
      };

      debug = mkOption {
        type = types.bool;
        default = false;
        description = "Enable debug mode";
      };
    };
  };

  # Type for test cases
  testCaseType = types.attrsOf types.attrs;

  # Type for deployment service options
  deploymentServiceOptionsType = types.submodule {
    options = {
      serviceName = mkOption {
        type = types.str;
        description = "Name of the service";
      };

      instanceName = mkOption {
        type = types.str;
        description = "Name of the service instance";
      };

      credentialMapping = mkOption {
        type = types.attrs;
        default = { };
        description = "Credential mapping for OpenTofu library compatibility";
      };

      dependencies = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Service dependencies";
      };

      backendType = mkOption {
        type = types.str;
        default = "local";
        description = "Terraform backend type";
      };

      timeoutSec = mkOption {
        type = types.str;
        default = "10m";
        description = "Deployment timeout";
      };

      preTerraformScript = mkOption {
        type = types.str;
        default = "";
        description = "Script to run before terraform execution";
      };

      postTerraformScript = mkOption {
        type = types.str;
        default = "";
        description = "Script to run after terraform execution";
      };

      validateConfig = mkOption {
        type = types.bool;
        default = true;
        description = "Validate terranix configuration";
      };

      debugMode = mkOption {
        type = types.bool;
        default = false;
        description = "Enable debug mode";
      };

      prettyPrintJson = mkOption {
        type = types.bool;
        default = false;
        description = "Pretty print generated JSON";
      };
    };
  };
}
