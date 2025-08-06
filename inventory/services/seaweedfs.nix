_: {
  instances = {
    # Example: All-in-one SeaweedFS instance (master + volume + filer)
    "seaweedfs-all" = {
      module.name = "seaweedfs";
      module.input = "self";
      roles.server = {
        tags."storage" = { };
        settings = {
          # Run all components on one machine
          mode = "all";

          # Basic replication: 1 copy on same server
          replication = "000";

          # Volume size limit in MB
          volumeSize = 30000; # 30GB

          # Optional: Enable web UI access via domain
          # masterDomain = "seaweed-master.example.com";
          # filerDomain = "seaweed.example.com";
          # enableSSL = true;

          # Optional: Enable authentication
          # auth = {
          #   enable = true;
          #   adminUsername = "admin";
          # };

          # Optional: Enable S3 API compatibility
          # s3 = {
          #   enable = true;
          #   port = 8333;
          #   domain = "s3.example.com";
          # };
        };
      };
    };

    # Example: Dedicated master server
    "seaweedfs-master" = {
      module.name = "seaweedfs";
      module.input = "self";
      roles.server = {
        tags."storage-master" = { };
        settings = {
          mode = "master";

          # Master with domain for cluster access
          masterDomain = "seaweed-master.example.com";
          enableSSL = true;

          # Replication strategy: 1 replica on different servers
          replication = "001";
          volumeSize = 50000; # 50GB volumes

          # Data center configuration for rack-aware placement
          dataCenter = "dc1";
          rack = "rack1";

          # Enable authentication for secure cluster
          auth = {
            enable = true;
            adminUsername = "admin";
          };
        };
      };
    };

    # Example: Volume server
    "seaweedfs-volume-1" = {
      module.name = "seaweedfs";
      module.input = "self";
      roles.server = {
        tags."storage-volume" = { };
        settings = {
          mode = "volume";

          # Connect to master servers
          masterServers = [ "seaweed-master.example.com:9333" ];

          # Same data center, different rack
          dataCenter = "dc1";
          rack = "rack2";
        };
      };
    };

    # Example: Filer server with S3 API
    "seaweedfs-filer" = {
      module.name = "seaweedfs";
      module.input = "self";
      roles.server = {
        tags."storage-filer" = { };
        settings = {
          mode = "filer";

          # Connect to master servers
          masterServers = [ "seaweed-master.example.com:9333" ];

          # Public-facing filer with domain
          filerDomain = "files.example.com";
          enableSSL = true;

          # Enable S3-compatible API
          s3 = {
            enable = true;
            port = 8333;
            domain = "s3.example.com";
          };

          # Same data center
          dataCenter = "dc1";
          rack = "rack1";
        };
      };
    };

    # Example: Simple local development instance
    "seaweedfs-dev" = {
      module.name = "seaweedfs";
      module.input = "self";
      roles.server = {
        tags."seaweedfs-dev" = { };
        settings = {
          mode = "all";
          replication = "000"; # No replication for dev
          volumeSize = 10000; # 10GB volumes

          # No authentication for development
          auth.enable = false;

          # Enable S3 API for testing
          s3 = {
            enable = true;
            port = 8333;
          };
        };
      };
    };
  };
}
