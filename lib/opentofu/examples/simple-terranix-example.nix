# Example showing how to use the enhanced OpenTofu library with terranix modules
{ lib, pkgs }:

let
  # Import the enhanced OpenTofu library
  opentofu = import ../default.nix { inherit lib pkgs; };

  # Example terranix module
  exampleTerranixModule = _: {
    # Terraform configuration
    terraform = {
      required_providers = {
        null = {
          source = "registry.opentofu.org/hashicorp/null";
          version = "~> 3.0";
        };
      };
      required_version = ">= 1.0.0";
    };

    # Variables
    variable = {
      example_message = {
        description = "An example message";
        type = "string";
        default = "Hello from Terranix!";
      };
    };

    # Resources
    resource = {
      null_resource.example = {
        triggers = {
          message = "\${var.example_message}";
        };

        provisioner = [
          {
            local-exec = {
              command = "echo '\${var.example_message}'";
            };
          }
        ];
      };
    };

    # Outputs
    output = {
      message = {
        description = "The example message";
        value = "\${var.example_message}";
      };
    };
  };

in
{
  # Example 1: Basic terranix module evaluation
  evaluatedModule = opentofu.evalTerranixModule {
    module = exampleTerranixModule;
    moduleArgs = {
      settings = {
        message = "Hello from enhanced OpenTofu!";
      };
    };
    validate = true;
    debug = true;
  };

  # Example 2: Generate JSON configuration
  jsonConfig = opentofu.generateTerranixJson {
    module = exampleTerranixModule;
    fileName = "example-terraform.json";
    validate = true;
  };

  # Example 3: Enhanced deployment service using terranix
  deploymentService = opentofu.mkDeploymentService {
    serviceName = "example";
    instanceName = "main";
    terranixModule = exampleTerranixModule;
    terranixModuleArgs = {
      settings = {
        message = "Deployed with terranix!";
      };
    };
    credentialMapping = { };
    terranixValidate = true;
    terranixDebug = false;
  };

  # Example 4: Validation utilities
  # Note: These are commented out as they depend on functions that are temporarily disabled
  # validation = opentofu.validateTerranixService {
  #   serviceName = "example";
  #   instanceName = "main";
  #   terranixModule = exampleTerranixModule;
  #   expectedBlocks = [ "terraform" "resource" "output" ];
  # };

  # Example 5: Testing utilities
  # testResults = opentofu.testTerranixModule {
  #   module = exampleTerranixModule;
  #   testCases = {
  #     "basic" = {};
  #     "with-settings" = { settings = { message = "Test message"; }; };
  #   };
  #   expectedBlocks = [ "terraform" "resource" ];
  # };

  # Example 6: Introspection
  # introspection = opentofu.introspectTerranixModule {
  #   module = exampleTerranixModule;
  # };
}
