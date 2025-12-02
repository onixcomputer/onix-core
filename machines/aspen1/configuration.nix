{ config, pkgs, ... }:
{
  networking = {
    hostName = "aspen1";
  };

  time.timeZone = "America/New_York";

  # Install terraform/tofu for Keycloak terraform integration
  environment.systemPackages = with pkgs; [
    opentofu # OpenTofu (Terraform fork)
  ];

  services = {
    # Garage S3-compatible storage for Terraform backend
    garage = {
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

    # Music Assistant - Music library and streaming service
    music-assistant = {
      enable = true;
    };

    # Radicle - Decentralized code collaboration
    radicle = {
      enable = true;
      privateKeyFile = config.clan.core.vars.generators."radicle-aspen1".files.ssh_private_key.path;
      publicKey = config.clan.core.vars.generators."radicle-aspen1".files.ssh_public_key.path;
      node = {
        listenAddress = "0.0.0.0";
        listenPort = 8776;
        openFirewall = true;
      };
      httpd = {
        enable = true;
        listenAddress = "0.0.0.0";
        listenPort = 8777;
      };
      settings = {
        node = {
          alias = "aspen1-seed";
          seedingPolicy = {
            default = "allow";
            scope = "all";
          };
        };
      };

      # Radicle CI - Continuous integration for Radicle repositories
      ci.broker = {
        enable = true;
        settings = {
          triggers = [
            {
              adapter = "default";
              filters = [
                {
                  And = [
                    { HasFile = ".radicle/native.yaml"; }
                    {
                      Or = [
                        "DefaultBranch"
                        "PatchCreated"
                        "PatchUpdated"
                      ];
                    }
                  ];
                }
              ];
            }
          ];
        };
      };

      # Radicle Native CI adapter
      ci.adapters.native.instances.default = {
        enable = true;
        runtimePackages = with pkgs; [
          bash
          coreutils
          curl
          gawk
          gitMinimal
          gnused
          wget
          nix
        ];
      };
    };
  };

  # Generate SSH keys for Radicle
  clan.core.vars.generators."radicle-aspen1" = {
    files.ssh_private_key = {
      owner = "radicle";
      group = "radicle";
      mode = "0600";
      secret = true;
      deploy = true;
    };
    files.ssh_public_key = {
      owner = "radicle";
      group = "radicle";
      mode = "0644";
      secret = false;
      deploy = true;
    };
    runtimeInputs = with pkgs; [
      openssh
      coreutils
    ];
    script = ''
      ssh-keygen -t ed25519 -f "$out/ssh_private_key" -N "" -C "radicle@aspen1"
      ssh-keygen -y -f "$out/ssh_private_key" > "$out/ssh_public_key"
    '';
  };
}
