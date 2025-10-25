# OpenTofu Path Generation Functions
#
# Pure functions for generating consistent file paths, service names,
# and script names for OpenTofu deployments. These functions ensure
# standardized naming conventions across the system.
_:

{
  # Generate service name from service and instance
  #
  # Creates a consistent service name by combining the service name
  # with the instance name using a hyphen separator.
  #
  # Type: String -> String -> String
  #
  # Example:
  #   makeServiceName "postgres" "primary" => "postgres-primary"
  makeServiceName = serviceName: instanceName: "${serviceName}-${instanceName}";

  # Generate state directory path
  #
  # Creates the path where terraform state and working files are stored
  # for a specific service instance.
  #
  # Type: String -> String -> String
  #
  # Example:
  #   makeStateDirectory "postgres" "primary" => "/var/lib/postgres-primary-terraform"
  makeStateDirectory = serviceName: instanceName: "/var/lib/${serviceName}-${instanceName}-terraform";

  # Generate terraform lock file path
  #
  # Creates the path to the terraform lock file for dependency locking.
  #
  # Type: String -> String -> String
  #
  # Example:
  #   makeLockFile "postgres" "primary" => "/var/lib/postgres-primary-terraform/.terraform.lock"
  makeLockFile =
    serviceName: instanceName: "/var/lib/${serviceName}-${instanceName}-terraform/.terraform.lock";

  # Generate terraform lock info file path
  #
  # Creates the path to the terraform lock info file for lock metadata.
  #
  # Type: String -> String -> String
  #
  # Example:
  #   makeLockInfoFile "postgres" "primary" => "/var/lib/postgres-primary-terraform/.terraform.lock.info"
  makeLockInfoFile =
    serviceName: instanceName: "/var/lib/${serviceName}-${instanceName}-terraform/.terraform.lock.info";

  # Generate deployment completion marker file path
  #
  # Creates the path to a file that indicates successful deployment completion.
  #
  # Type: String -> String -> String
  #
  # Example:
  #   makeDeployCompleteFile "postgres" "primary" => "/var/lib/postgres-primary-terraform/.deploy-complete"
  makeDeployCompleteFile =
    serviceName: instanceName: "/var/lib/${serviceName}-${instanceName}-terraform/.deploy-complete";

  # Generate deployment service name
  #
  # Creates the systemd service name for the terraform deployment service.
  #
  # Type: String -> String -> String
  #
  # Example:
  #   makeDeploymentServiceName "postgres" "primary" => "postgres-terraform-deploy-primary"
  makeDeploymentServiceName =
    serviceName: instanceName: "${serviceName}-terraform-deploy-${instanceName}";

  # Generate garage initialization service name
  #
  # Creates the systemd service name for garage S3 backend initialization.
  #
  # Type: String -> String
  #
  # Example:
  #   makeGarageInitServiceName "primary" => "garage-terraform-init-primary"
  makeGarageInitServiceName = instanceName: "garage-terraform-init-${instanceName}";

  # Generate unlock script name
  #
  # Creates the name for the terraform state unlock helper script.
  #
  # Type: String -> String -> String
  #
  # Example:
  #   makeUnlockScriptName "postgres" "primary" => "postgres-tf-unlock-primary"
  makeUnlockScriptName = serviceName: instanceName: "${serviceName}-tf-unlock-${instanceName}";

  # Generate status script name
  #
  # Creates the name for the terraform status check helper script.
  #
  # Type: String -> String -> String
  #
  # Example:
  #   makeStatusScriptName "postgres" "primary" => "postgres-tf-status-primary"
  makeStatusScriptName = serviceName: instanceName: "${serviceName}-tf-status-${instanceName}";

  # Generate apply script name
  #
  # Creates the name for the terraform apply helper script.
  #
  # Type: String -> String -> String
  #
  # Example:
  #   makeApplyScriptName "postgres" "primary" => "postgres-tf-apply-primary"
  makeApplyScriptName = serviceName: instanceName: "${serviceName}-tf-apply-${instanceName}";

  # Generate logs script name
  #
  # Creates the name for the deployment logs helper script.
  #
  # Type: String -> String -> String
  #
  # Example:
  #   makeLogsScriptName "postgres" "primary" => "postgres-tf-logs-primary"
  makeLogsScriptName = serviceName: instanceName: "${serviceName}-tf-logs-${instanceName}";
}
