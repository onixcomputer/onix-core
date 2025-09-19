_: {
  terraform.required_version = ">= 1.0";

  # Backend is configured in backend.tf (S3 with Garage)

  # Development environment resources
  resource.null_resource.dev_test = {
    provisioner."local-exec" = {
      command = "echo '🔧 Development Environment - Infrastructure as Code'";
    };
  };

  # Example: Development DNS records (if using Cloudflare)
  # resource.cloudflare_record.dev_subdomain = {
  #   zone_id = "your-zone-id";
  #   name = "dev";
  #   content = "192.168.1.100";
  #   type = "A";
  #   ttl = 300;
  #   comment = "Development environment";
  # };

  # Development environment outputs
  output.environment = {
    value = "development";
  };

  output.state_location = {
    value = "Encrypted in Clan vars: terraform-state-infrastructure-dev";
  };
}
