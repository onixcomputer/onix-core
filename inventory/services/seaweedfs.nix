_: {
  instances = {
    # Distributed SeaweedFS: Master + Filer + Volume (britton-fw)
    "seaweedfs-master-fw" = {
      module.name = "seaweedfs";
      module.input = "self";
      roles.server = {
        tags."seaweedfs-master" = { };
        settings = {
          mode = "all"; # Master + Volume + Filer on this machine
          replication = "010"; # Replicate to different rack
          volumeSize = 20000; # 20GB volumes

          # No authentication for development
          auth.enable = false;

          # Enable S3 API for testing
          s3 = {
            enable = true;
            port = 8333;
          };

          # Use different filer port to avoid conflict with static-web-server
          filerPort = 8890;

          # Use Traefik for private access
          useTraefik = true;

          # Cluster configuration
          dataCenter = "home";
          rack = "fw";

          # Advertise actual Tailscale IP
          publicIp = "100.92.36.3";
        };
      };
    };

    # Distributed SeaweedFS: Volume Server (britton-desktop)
    "seaweedfs-volume-desktop" = {
      module.name = "seaweedfs";
      module.input = "self";
      roles.server = {
        tags."seaweedfs-volume" = { };
        settings = {
          mode = "volume"; # Only volume server

          # Connect to master on britton-fw (via Tailscale)
          masterServers = [ "100.92.36.3:9333" ]; # britton-fw Tailscale IP

          # Cluster configuration
          dataCenter = "home";
          rack = "desktop";

          volumeSize = 20000; # 20GB volumes

          # Advertise actual Tailscale IP
          publicIp = "100.110.43.11";
        };
      };
    };
  };
}
