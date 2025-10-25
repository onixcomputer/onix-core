# OpenTofu Configuration Analysis Utilities
#
# Pure functions for extracting information from terranix configurations,
# analyzing service components, and providing debugging/testing utilities.
{ lib }:

{
  # Extract variable names from terranix configuration
  #
  # Analyzes a terranix configuration and returns a list of all
  # declared variable names for dependency analysis and validation.
  #
  # Type: AttrSet -> [String]
  #
  # Example:
  #   extractVariables { variable = { db_password = { }; region = { }; }; }
  #   => [ "db_password" "region" ]
  extractVariables = config: if config ? variable then builtins.attrNames config.variable else [ ];

  # Extract resource information from terranix configuration
  #
  # Analyzes a terranix configuration and returns a list of all
  # declared resources with their types and names for inventory
  # and dependency tracking.
  #
  # Type: AttrSet -> [{ type: String; name: String; }]
  #
  # Example:
  #   extractResources { resource = { aws_instance = { web = { }; }; aws_vpc = { main = { }; }; }; }
  #   => [ { type = "aws_instance"; name = "web"; } { type = "aws_vpc"; name = "main"; } ]
  extractResources =
    config:
    if config ? resource then
      lib.flatten (
        lib.mapAttrsToList (
          type: resources: map (name: { inherit type name; }) (builtins.attrNames resources)
        ) config.resource
      )
    else
      [ ];

  # Extract all service components for debugging and testing
  #
  # Given a service name and instance name, generates a comprehensive
  # attribute set containing all related paths, service names, and
  # script names for debugging and testing purposes.
  #
  # Type: String -> String -> AttrSet
  #
  # Example:
  #   extractServiceComponents "postgres" "primary"
  #   => {
  #     stateDir = "/var/lib/postgres-primary-terraform";
  #     lockFile = "/var/lib/postgres-primary-terraform/.terraform.lock";
  #     lockInfoFile = "/var/lib/postgres-primary-terraform/.terraform.lock.info";
  #     deploymentServiceName = "postgres-terraform-deploy-primary";
  #     scriptNames = {
  #       unlock = "postgres-tf-unlock-primary";
  #       status = "postgres-tf-status-primary";
  #       apply = "postgres-tf-apply-primary";
  #       logs = "postgres-tf-logs-primary";
  #     };
  #   }
  extractServiceComponents = serviceName: instanceName: {
    stateDir = "/var/lib/${serviceName}-${instanceName}-terraform";
    lockFile = "/var/lib/${serviceName}-${instanceName}-terraform/.terraform.lock";
    lockInfoFile = "/var/lib/${serviceName}-${instanceName}-terraform/.terraform.lock.info";
    deploymentServiceName = "${serviceName}-terraform-deploy-${instanceName}";
    scriptNames = {
      unlock = "${serviceName}-tf-unlock-${instanceName}";
      status = "${serviceName}-tf-status-${instanceName}";
      apply = "${serviceName}-tf-apply-${instanceName}";
      logs = "${serviceName}-tf-logs-${instanceName}";
    };
  };
}
