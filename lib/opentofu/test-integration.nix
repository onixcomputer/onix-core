# OpenTofu Library Integration Tests - For derivation-based functions
# Run via: nix build .#legacyPackages.x86_64-linux.opentofu-integration-tests
{ pkgs, lib, ... }:

let
  # Import the full opentofu library with derivations
  opentofu = import ./default.nix { inherit lib pkgs; };

  # Create a dummy terraform config file for testing
  testTerraformConfig = pkgs.writeText "test-config.json" ''
    {
      "terraform": {
        "required_version": ">= 1.0"
      },
      "provider": {
        "null": {
          "source": "hashicorp/null",
          "version": "~> 3.0"
        }
      },
      "resource": {
        "null_resource": {
          "test": {
            "provisioner": {
              "local-exec": {
                "command": "echo test"
              }
            }
          }
        }
      }
    }
  '';

  # Test helper scripts generation
  testHelperScripts = opentofu.mkHelperScripts {
    serviceName = "test";
    instanceName = "unit";
  };

  # Test activation script generation
  testActivationScript = opentofu.mkActivationScript {
    serviceName = "test";
    instanceName = "unit";
    terraformConfigPath = testTerraformConfig;
  };

  # Test deployment service generation
  testCredentialMapping = {
    "admin_password" = "admin_password";
  };
  testDeploymentService = opentofu.mkDeploymentService {
    serviceName = "test";
    instanceName = "unit";
    terraformConfigPath = testTerraformConfig;
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
  simpleTerranixModule = _: {
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
        activation_text_length=$(echo "${testActivationScript.text}" | wc -c)
        test "$activation_text_length" -gt 0
        echo "✓ Activation script has text: OK"

        deps_string="${toString testActivationScript.deps}"
        test -n "$deps_string"
        echo "✓ Activation script has deps: OK"

        # Check for expected content in activation script
        echo "Checking activation script content..."
        activation_text_file=$(mktemp)
        cat > "$activation_text_file" <<'EOF'
    ${testActivationScript.text}
    EOF
        grep -q "configuration changes" "$activation_text_file"
        echo "✓ Activation script has change detection: OK"
        rm -f "$activation_text_file"

        echo "Testing deployment service generation..."
        deployment_service_file=$(mktemp)
        cat > "$deployment_service_file" <<'EOF'
    ${builtins.toJSON testDeploymentService}
    EOF
        grep -q "test-terraform-deploy-unit" "$deployment_service_file"
        echo "✓ Deployment service has correct name: OK"

        # Check service configuration
        grep -q "oneshot" "$deployment_service_file"
        echo "✓ Deployment service is oneshot: OK"

        grep -q "admin_password" "$deployment_service_file"
        echo "✓ Deployment service has credentials: OK"

        echo "Testing garage init service generation..."
        garage_service_file=$(mktemp)
        cat > "$garage_service_file" <<'EOF'
    ${builtins.toJSON testGarageService}
    EOF
        grep -q "garage-terraform-init-unit" "$garage_service_file"
        echo "✓ Garage service has correct name: OK"

        grep -q "garage.service" "$garage_service_file"
        echo "✓ Garage service depends on garage: OK"
        rm -f "$garage_service_file"

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
        terranix_config_file=$(mktemp)
        cat > "$terranix_config_file" <<'EOF'
    ${builtins.toJSON testTerranixConfig}
    EOF
        grep -q "terraform" "$terranix_config_file"
        grep -q "provider" "$terranix_config_file"
        grep -q "variable" "$terranix_config_file"
        grep -q "resource" "$terranix_config_file"
        grep -q "output" "$terranix_config_file"
        echo "✓ Terranix config has all sections: OK"

        grep -q "null_resource" "$terranix_config_file"
        echo "✓ Terranix config has expected resources: OK"
        rm -f "$terranix_config_file"

        echo "Testing terranix-based deployment..."
        terranix_deployment_file=$(mktemp)
        cat > "$terranix_deployment_file" <<'EOF'
    ${builtins.toJSON testTerranixDeployment}
    EOF
        grep -q "terranix-test-terraform-deploy-integration" "$terranix_deployment_file"
        echo "✓ Terranix deployment service created: OK"

        grep -q "test_token" "$terranix_deployment_file"
        echo "✓ Terranix deployment has credentials: OK"

        echo "Testing service dependencies..."
        grep -q "test.service" "$deployment_service_file"
        echo "✓ Deployment service has dependencies: OK"

        grep -q "terranix-test.service" "$terranix_deployment_file"
        echo "✓ Terranix deployment has dependencies: OK"

        # Clean up temporary files
        rm -f "$deployment_service_file" "$terranix_deployment_file"

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
