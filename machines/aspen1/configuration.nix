{ pkgs, ... }:
{
  networking = {
    hostName = "aspen1";
  };

  time.timeZone = "America/New_York";

  # Install terraform/tofu for Keycloak terraform integration
  environment.systemPackages = with pkgs; [
    opentofu # OpenTofu (Terraform fork)
  ];
}
