{ ... }:
{
  instances = {

    # Test VM instance for development and testing
    "test-vm" = {
      module.name = "microvm";
      module.input = "self";
      roles.server = {
        tags."desktop" = { };
        settings = {
          vmName = "test-vm";
          autostart = true;
          hypervisor = "cloud-hypervisor";
          vcpu = 2;
          mem = 1024;

          # Network configuration
          interfaces = [
            {
              type = "tap";
              id = "vm-test";
              mac = "02:00:00:01:01:01";
            }
          ];

          # Enable vsock for systemd notification
          vsockCid = 3;

          # Credentials to pass from host
          credentials = {
            api-key = {
              source = "/run/secrets/test-vm-secrets/api-key";
              destination = "API-KEY";
            };
            db-password = {
              source = "/run/secrets/test-vm-secrets/db-password";
              destination = "DB-PASSWORD";
            };
            jwt-secret = {
              source = "/run/secrets/test-vm-secrets/jwt-secret";
              destination = "JWT-SECRET";
            };
          };

          # Static configuration via OEM strings
          staticOemStrings = [
            "io.systemd.credential:ENVIRONMENT=test"
            "io.systemd.credential:CLUSTER=britton-desktop"
          ];

          # Guest configuration
          rootPassword = "test"; # For testing only!
          firewallPorts = [
            80
            443
          ];

          # Guest packages
          guestPackages = [ ];
        };
      };
    };

    # Vault VM with enhanced security
    "vault-vm" = {
      module.name = "microvm";
      module.input = "self";
      roles.server = {
        tags."desktop" = { };
        settings = {
          vmName = "vault";
          autostart = false; # Manual start only
          hypervisor = "cloud-hypervisor";

          # More resources for vault
          vcpu = 4;
          mem = 2048;

          # Network with static IP
          interfaces = [
            {
              type = "tap";
              id = "vm-vault";
              mac = "02:00:00:02:02:02";
            }
          ];

          vsockCid = 4;

          # Vault-specific credentials
          credentials = {
            unseal-key = {
              source = "/run/secrets/vault-secrets/unseal-key";
              destination = "UNSEAL-KEY";
            };
            root-token = {
              source = "/run/secrets/vault-secrets/root-token";
              destination = "ROOT-TOKEN";
            };
          };

          staticOemStrings = [
            "io.systemd.credential:ENVIRONMENT=production"
            "io.systemd.credential:ROLE=vault"
          ];

          # Enhanced security hardening
          serviceHardening = {
            enable = true;
            protectProc = "noaccess";
            procSubset = "pid";
            protectHome = true;
            restrictAddressFamilies = [
              "AF_UNIX"
              "AF_VSOCK"
              "AF_INET"
              "AF_INET6"
            ];
            systemCallFilter = [
              "@system-service"
              "~@privileged"
              "@resources"
              "@kvm"
            ];
          };

          # No root password - SSH key only
          rootPassword = null;
          authorizedKeys = [
            # Add your SSH public key here
            # "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."
          ];

          firewallPorts = [
            8200
            8201
          ]; # Vault API and cluster ports

          # Additional volumes for vault data
          volumes = [
            {
              image = "/var/lib/microvms/vault/data.img";
              mountPoint = "/vault/data";
              size = 10240; # 10GB
              fsType = "ext4";
              autoCreate = true;
            }
          ];

          # Note: Vault configuration should be added via guestModules in the module
          guestPackages = [ ];
        };
      };
    };

    # Development container VM
    "dev-container" = {
      module.name = "microvm";
      module.input = "self";
      roles.server = {
        tags."desktop" = { };
        settings = {
          vmName = "dev-container";
          autostart = false;
          hypervisor = "cloud-hypervisor";

          # Minimal resources for development
          vcpu = 1;
          mem = 512;

          interfaces = [
            {
              type = "tap";
              id = "vm-dev";
              mac = "02:00:00:03:03:03";
            }
          ];

          # Share development directories
          shares = [
            {
              tag = "ro-store";
              source = "/nix/store";
              mountPoint = "/nix/.ro-store";
              proto = "virtiofs";
            }
            {
              tag = "dev-home";
              source = "/home/brittonr/projects";
              mountPoint = "/projects";
              proto = "virtiofs";
            }
          ];

          rootPassword = "dev";

          # Development packages
          guestPackages = [ ];
        };
      };
    };

  };
}
