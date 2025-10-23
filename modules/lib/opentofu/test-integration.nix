# OpenTofu Library Integration Tests - For derivation-based functions
# Run via: nix build .#legacyPackages.x86_64-linux.opentofu-integration-tests
{ pkgs, lib }:

let
  # Import the full opentofu library with derivations
  opentofu = import ./default.nix { inherit lib pkgs; };

  # Test helper scripts generation
  testHelperScripts = opentofu.mkHelperScripts {
    serviceName = "test";
    instanceName = "unit";
  };

  # Test activation script generation
  testActivationScript = opentofu.mkActivationScript {
    serviceName = "test";
    instanceName = "unit";
    terraformConfigPath = "/test/path/config.json";
  };

  # Test deployment service generation
  testCredentialMapping = {
    "admin_password" = "admin_password";
  };
  testDeploymentService = opentofu.mkDeploymentService {
    serviceName = "test";
    instanceName = "unit";
    terraformConfigPath = "/test/path/config.json";
    credentialMapping = testCredentialMapping;
    dependencies = [ "test.service" ];
  };

  # Test garage init service generation
  testGarageService = opentofu.mkGarageInitService {
    serviceName = "test";
    instanceName = "unit";
  };

  # Test multiple service pattern
  service1Scripts = opentofu.mkHelperScripts {
    serviceName = "service1";
    instanceName = "prod";
  };
  service2Scripts = opentofu.mkHelperScripts {
    serviceName = "service2";
    instanceName = "dev";
  };

  # Simple terranix module for testing
  simpleTerranixModule =
    { ... }:
    {
      terraform.required_version = ">= 1.0";
      provider.null = {
        source = "hashicorp/null";
        version = "~> 3.0";
      };
      variable.test_var = {
        description = "Test variable";
        type = "string";
        default = "test";
      };
      resource.null_resource.test = {
        provisioner.local-exec = {
          command = "echo \${var.test_var}";
        };
      };
      output.test_output = {
        value = "\${null_resource.test.id}";
        description = "Test resource ID";
      };
    };

  # Test terranix module evaluation
  testTerranixConfig = opentofu.evalTerranixModule {
    module = simpleTerranixModule;
    moduleArgs = { inherit lib; };
  };

  # Test terranix-based deployment service
  testTerranixDeployment = opentofu.mkDeploymentService {
    serviceName = "terranix-test";
    instanceName = "integration";
    terranixModule = simpleTerranixModule;
    terranixModuleArgs = { inherit lib; };
    credentialMapping = {
      "test_token" = "test_secret";
    };
    dependencies = [ "terranix-test.service" ];
  };

in
pkgs.runCommand "opentofu-integration-tests"
  {
    preferLocalBuild = true;
  }
  ''
    echo "=== OpenTofu Library Integration Tests ==="

    echo "Testing helper scripts generation..."
    test ${toString (builtins.length testHelperScripts)} -eq 4
    echo "✓ Helper scripts count: OK (${toString (builtins.length testHelperScripts)})"

    # Check that scripts are derivations
    first_script="${builtins.head testHelperScripts}"
    test -n "$first_script"
    echo "✓ Helper scripts are derivations: OK"

    # Verify script names contain expected patterns
    script_names=""
    ${lib.concatMapStringsSep "\n" (script: ''
      script_names="$script_names $(basename ${script})"
    '') testHelperScripts}

    echo "Script names: $script_names"
    echo "$script_names" | grep -q "test-tf-unlock-unit"
    echo "$script_names" | grep -q "test-tf-status-unit"
    echo "$script_names" | grep -q "test-tf-apply-unit"
    echo "$script_names" | grep -q "test-tf-logs-unit"
    echo "✓ Helper script naming: OK"

    echo "Testing activation script generation..."
    test -n "${testActivationScript.text}"
    echo "✓ Activation script has text: OK"

    test -n "${toString testActivationScript.deps}"
    echo "✓ Activation script has deps: OK"

    # Check for expected content in activation script
    activation_text='${testActivationScript.text}'
    echo "$activation_text" | grep -q "configuration changes"
    echo "✓ Activation script has change detection: OK"

    echo "Testing deployment service generation..."
    deployment_service='${builtins.toJSON testDeploymentService}'
    echo "$deployment_service" | grep -q "test-terraform-deploy-unit"
    echo "✓ Deployment service has correct name: OK"

    # Check service configuration
    echo "$deployment_service" | grep -q "oneshot"
    echo "✓ Deployment service is oneshot: OK"

    echo "$deployment_service" | grep -q "admin_password"
    echo "✓ Deployment service has credentials: OK"

    echo "Testing garage init service generation..."
    garage_service='${builtins.toJSON testGarageService}'
    echo "$garage_service" | grep -q "garage-terraform-init-unit"
    echo "✓ Garage service has correct name: OK"

    echo "$garage_service" | grep -q "garage.service"
    echo "✓ Garage service depends on garage: OK"

    echo "Testing multiple service isolation..."
    service1_names=""
    ${lib.concatMapStringsSep "\n" (script: ''
      service1_names="$service1_names $(basename ${script})"
    '') service1Scripts}

    service2_names=""
    ${lib.concatMapStringsSep "\n" (script: ''
      service2_names="$service2_names $(basename ${script})"
    '') service2Scripts}

    echo "Service1 scripts: $service1_names"
    echo "Service2 scripts: $service2_names"

    echo "$service1_names" | grep -q "service1-tf-"
    echo "$service2_names" | grep -q "service2-tf-"
    echo "✓ Multiple services have unique names: OK"

    echo "Testing terranix module evaluation..."
    terranix_config='${builtins.toJSON testTerranixConfig}'
    echo "$terranix_config" | grep -q "terraform"
    echo "$terranix_config" | grep -q "provider"
    echo "$terranix_config" | grep -q "variable"
    echo "$terranix_config" | grep -q "resource"
    echo "$terranix_config" | grep -q "output"
    echo "✓ Terranix config has all sections: OK"

    echo "$terranix_config" | grep -q "null_resource"
    echo "✓ Terranix config has expected resources: OK"

    echo "Testing terranix-based deployment..."
    terranix_deployment='${builtins.toJSON testTerranixDeployment}'
    echo "$terranix_deployment" | grep -q "terranix-test-terraform-deploy-integration"
    echo "✓ Terranix deployment service created: OK"

    echo "$terranix_deployment" | grep -q "test_token"
    echo "✓ Terranix deployment has credentials: OK"

    echo "Testing service dependencies..."
    echo "$deployment_service" | grep -q "test.service"
    echo "✓ Deployment service has dependencies: OK"

    echo "$terranix_deployment" | grep -q "terranix-test.service"
    echo "✓ Terranix deployment has dependencies: OK"

    echo ""
    echo "=== Integration Test Summary ==="
    echo "✓ Helper scripts generation"
    echo "✓ Activation script generation"
    echo "✓ Deployment service generation"
    echo "✓ Garage init service generation"
    echo "✓ Multiple service isolation"
    echo "✓ Terranix module evaluation"
    echo "✓ Terranix-based deployment"
    echo "✓ Service dependencies"
    echo ""
    echo "🎉 All integration tests passed!"

    touch $out
  ''
