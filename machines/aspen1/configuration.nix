_: {
  networking = {
    hostName = "aspen1";
  };

  time.timeZone = "America/New_York";

  # Install terraform/tofu for Keycloak terraform integration
  environment.systemPackages = with pkgs; [
    opentofu # OpenTofu (Terraform fork)
  ];

  # Garage S3-compatible storage for Terraform backend
  services.garage = {
    enable = true;
    package = pkgs.garage;
    settings = {
      metadata_dir = "/var/lib/garage/meta";
      data_dir = "/var/lib/garage/data";
      db_engine = "sqlite";
      replication_factor = 1;

      rpc_bind_addr = "127.0.0.1:3901";
      rpc_public_addr = "127.0.0.1:3901";

      s3_api = {
        api_bind_addr = "127.0.0.1:3900";
        s3_region = "garage";
        root_domain = ".s3.garage.local";
      };

      s3_web = {
        bind_addr = "127.0.0.1:3902";
        root_domain = ".web.garage.local";
      };

      admin = {
        api_bind_addr = "127.0.0.1:3903";
      };
    };
  };
}
