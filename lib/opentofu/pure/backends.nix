# OpenTofu Backend Configuration Functions
#
# Pure functions for generating terraform backend configurations
# for different storage backends (S3/Garage and local storage).
_:

{
  # Generate S3 backend configuration
  #
  # Creates terraform backend configuration for S3-compatible storage,
  # specifically configured for Garage S3 with local endpoint.
  #
  # Type: { serviceName: String; instanceName: String; } -> String
  #
  # Example:
  #   generateS3BackendConfig { serviceName = "postgres"; instanceName = "primary"; }
  #   => Terraform configuration block for S3 backend
  generateS3BackendConfig =
    { serviceName, instanceName }:
    ''
      terraform {
        backend "s3" {
          endpoint = "http://127.0.0.1:3900"
          bucket = "terraform-state"
          key = "${serviceName}/${instanceName}/terraform.tfstate"
          region = "garage"
          skip_credentials_validation = true
          skip_metadata_api_check = true
          skip_region_validation = true
          force_path_style = true
        }
      }
    '';

  # Generate local backend configuration
  #
  # Creates terraform backend configuration for local file storage.
  # Useful for development and testing scenarios.
  #
  # Type: String
  #
  # Example:
  #   generateLocalBackendConfig
  #   => Terraform configuration block for local backend
  generateLocalBackendConfig = ''
    terraform {
      backend "local" {
        path = "terraform.tfstate"
      }
    }
  '';
}
