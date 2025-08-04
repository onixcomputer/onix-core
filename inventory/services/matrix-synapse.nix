_: {
  instances = {
    "matrix-synapse" = {
      module.name = "matrix-synapse";
      module.input = "self";
      roles.server = {
        tags."matrix" = { };
        settings = {
          # Clan-specific options
          server_name = "onix.computer"; # Your Matrix server name
          domain = "matrix.onix.computer"; # Where Matrix will be accessible

          # Enable Element web client
          enable_element = true;

          # Database configuration
          database = {
            type = "postgresql"; # or "sqlite3"
          };

          # Federation settings
          federation = {
            enabled = true; # Allow federation with other Matrix servers
          };

          # Registration settings
          registration = {
            enable = false; # Disable open registration
          };

          # Pre-configured users
          users = {
            # admin = { admin = true; };
            # user1 = { admin = false; };
          };

          # Additional Matrix Synapse configuration (freeform)
          # Any valid services.matrix-synapse option can be added here
          # settings = {
          #   max_upload_size = "50M";
          #   url_preview_enabled = true;
          #   url_preview_ip_range_blacklist = [
          #     "127.0.0.0/8"
          #     "10.0.0.0/8"
          #     "172.16.0.0/12"
          #     "192.168.0.0/16"
          #   ];
          # };

          # You can also override the package
          # package = pkgs.matrix-synapse-unstable;
        };
      };
    };
  };
}
