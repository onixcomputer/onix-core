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

  # Example 3: High-level service creation (RECOMMENDED APPROACH)
  # This creates a complete NixOS configuration with systemd services, activation scripts, and helper scripts
  completeService = opentofu.mkTerranixService {
    serviceName = "example";
    instanceName = "main";
    terranixModule = exampleTerranixModule;
    terranixModuleArgs = {
      settings = {
        message = "Complete service with terranix!";
      };
    };
    credentialMapping = { };
    backendType = "local";
    generateHelperScripts = true;
    terranixValidate = true;
    terranixDebug = false;
  };

  # Example 4: Lower-level deployment service (for advanced users)
  deploymentService = opentofu.mkTerranixInfrastructure {
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

  # Example 5: Quick deployment service (simplified wrapper)
  quickService = opentofu.mkTerranixDeployment {
    serviceName = "example";
    instanceName = "quick";
    terranixModule = exampleTerranixModule;
    credentialMapping = { };
    dependencies = [ ];
  };

  # Example 6: Testing utilities
  testResults = opentofu.testTerranixModule {
    module = exampleTerranixModule;
    testCases = {
      "basic" = { };
      "with-settings" = {
        settings = {
          message = "Test message";
        };
      };
    };
    expectedBlocks = [
      "terraform"
      "resource"
    ];
  };

  # Example 7: Introspection
  introspection = opentofu.introspectTerranixModule { module = exampleTerranixModule; };
}
