# Example: How to integrate the OpenTofu credential library in a clan service module

{ ... }:
let

  # Example usage in a service module like keycloak
  exampleIntegration =
    {
      instanceName,
      ...
    }:
    {
      nixosModule =
        { config, pkgs, ... }:
        let
          generatorName = "my-service-${instanceName}";

          # Define the credential mapping using the library
          credentialMapping = {
            "admin_password" = "admin_password";
            "database_password" = "db_password";
            # Advanced mapping example:
            "api_key" = {
              clanVarFile = "api_secret";
              generatorName = "shared-auth";
              optional = false;
            };
          };

          # Generate terraform configuration path
          terraformConfigJson = pkgs.writeText "my-service-terraform-${instanceName}.json" (
            builtins.toJSON {
              # terraform configuration here
            }
          );

        in
        {
          # Import the library
          imports = [ ../lib/opentofu ];

          # Configure the credential mapping
          opentofu.credentialMapping = credentialMapping;

          # Define clan vars generators
          clan.core.vars.generators.${generatorName} = {
            files = {
              admin_password = {
                deploy = true;
              };
              db_password = {
                deploy = true;
              };
            };
            runtimeInputs = [ pkgs.pwgen ];
            script = ''
              ${pkgs.pwgen}/bin/pwgen -s 32 1 | tr -d '\n' > "$out"/admin_password
              ${pkgs.pwgen}/bin/pwgen -s 32 1 | tr -d '\n' > "$out"/db_password
            '';
          };

          # Example systemd service using the library
          systemd.services."my-service-terraform-${instanceName}" = {
            description = "My Service Terraform execution";

            after = [ "my-service.service" ];
            requires = [ "my-service.service" ];

            path = [
              pkgs.opentofu
              pkgs.curl
              pkgs.jq
              pkgs.coreutils
            ];

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = false;
              StateDirectory = "my-service-${instanceName}-terraform";
              WorkingDirectory = "/var/lib/my-service-${instanceName}-terraform";
              TimeoutStartSec = "10m";

              # Use the library to generate LoadCredential entries
              LoadCredential = config._lib.opentofu.generateLoadCredentials generatorName credentialMapping;
            };

            script = ''
              set -euo pipefail

              echo "Starting terraform for my-service ${instanceName}"

              # Copy terraform configuration
              cp ${terraformConfigJson} ./main.tf.json

              # Use the library to generate terraform.tfvars
              ${config._lib.opentofu.generateTfvarsScript credentialMapping ""}

              # Initialize and apply terraform
              tofu init -upgrade -input=false

              set +e
              tofu plan -var-file=terraform.tfvars -detailed-exitcode -out=tfplan
              PLAN_EXIT=$?
              set -e

              case $PLAN_EXIT in
                0)
                  echo "No changes needed"
                  ;;
                1)
                  echo "Terraform plan failed"
                  exit 1
                  ;;
                2)
                  echo "Applying terraform changes..."
                  tofu apply -auto-approve tfplan
                  ;;
              esac
            '';
          };
        };
    };

in
{
  # This is just an example file showing integration patterns
  _example = exampleIntegration;
}
