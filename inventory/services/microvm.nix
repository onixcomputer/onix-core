_: {
  instances = {

    # Test VM on desktop
    test-vm = {
      module.name = "microvm";
      module.input = "self";
      roles.server = {
        machines."britton-desktop" = {
          settings = {
            # Guest configuration
            guestConfig = ../../machines/test-vm/configuration.nix;

            # Credentials to generate and pass to guest
            credentials = {
              "api-key" = "API_KEY";
              "db-password" = "DB_PASSWORD";
              "jwt-secret" = "JWT_SECRET";
            };

            # Enable SSH access
            enableSSH = true;

            # MicroVM configuration (uses freeformType)
            vmName = "test-vm";
            autostart = true;
            hypervisor = "cloud-hypervisor";
            vcpu = 2;
            mem = 1024;
            vsockCid = 3;

            # Network configuration
            interfaces = [
              {
                type = "tap";
                id = "vm-test";
                mac = "02:00:00:01:01:01";
              }
            ];
          };
        };
      };
    };

    # Monitoring VM on desktop
    monitoring-vm = {
      module.name = "microvm";
      module.input = "self";
      roles.server = {
        machines."desktop" = {
          settings = {
            # Guest configuration
            guestConfig = ../../machines/monitoring-vm/configuration.nix;

            # Monitoring-specific credentials
            credentials = {
              "grafana-admin-password" = "GRAFANA_ADMIN_PASSWORD";
              "prometheus-token" = "PROMETHEUS_TOKEN";
              "loki-auth-token" = "LOKI_AUTH_TOKEN";
              "webhook-secret" = "WEBHOOK_SECRET";
              "monitoring-api-key" = "MONITORING_API_KEY";
            };

            # Enable SSH access
            enableSSH = true;

            # MicroVM configuration (uses freeformType)
            vmName = "monitoring-vm";
            autostart = true;
            hypervisor = "cloud-hypervisor";
            vcpu = 2;
            mem = 2048; # More memory for monitoring services
            vsockCid = 4;

            # Network configuration with unique MAC
            interfaces = [
              {
                type = "tap";
                id = "vm-monitor";
                mac = "02:00:00:02:02:02";
              }
            ];
          };
        };
      };
    };

    # Example: Same VM on different host (commented out)
    # test-vm-on-ultrathink = {
    #   module.name = "microvm";
    #   module.input = "self";
    #   roles.server = {
    #     machines."ultrathink" = {
    #       settings = {
    #         # Guest configuration (shared)
    #         guestConfig = ../../machines/test-vm/configuration.nix;
    #
    #         # Same credentials
    #         credentials = {
    #           "api-key" = "API_KEY";
    #           "db-password" = "DB_PASSWORD";
    #           "jwt-secret" = "JWT_SECRET";
    #         };
    #
    #         # MicroVM configuration (different specs for laptop)
    #         vmName = "test-vm";
    #         autostart = false;
    #         vcpu = 1;    # Less CPU for laptop
    #         mem = 512;   # Less memory for laptop
    #         vsockCid = 3;
    #
    #         interfaces = [
    #           {
    #             type = "tap";
    #             id = "vm-test";
    #             mac = "02:00:00:01:01:01";
    #           }
    #         ];
    #       };
    #     };
    #   };
    # };

  };
}
