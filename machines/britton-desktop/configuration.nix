{
  inputs,
  pkgs,
  config,
  ...
}:
let
  grubWallpaper = pkgs.fetchurl {
    name = "nixos-grub-wallpaper.jpg";
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/nix-grub-3840x2160.png";
    sha256 = "sha256-d+sXYC74KL90wh06bLYTgebF6Ai7ac6Qsd+6qj57yyE=";
  };
in
{
  imports = [
    inputs.grub2-themes.nixosModules.default
    inputs.microvm.nixosModules.host
  ];

  networking = {
    hostName = "britton-desktop";
    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ];
  };

  time.timeZone = "America/New_York";
  time.hardwareClockInLocalTime = true; # Prevent time sync issues with Windows

  environment.systemPackages = with pkgs; [
    imagemagick # required for grub2-theme
    os-prober
  ];

  boot.loader = {
    timeout = 1;
    grub = {
      timeoutStyle = "menu";
      enable = true;
      device = "nodev";
      efiSupport = true;
      useOSProber = true;
      extraConfig = ''
        GRUB_DISABLE_OS_PROBER=false
      '';
      extraEntries = ''
        menuentry "Reboot" {
          reboot
        }
      '';
      # extraEntries = ''
      #   menuentry "Windows (Manual)" {
      #     insmod part_gpt
      #     insmod ntfs
      #     insmod search_fs_uuid
      #     insmod chain
      #     search --fs-uuid --set=root 12EA42E8EA42C825
      #     chainloader +1
      #   }
      # '';
    };
    grub2-theme = {
      enable = true;
      theme = "stylish";
      footer = true;
      customResolution = "3840x2160";
      splashImage = grubWallpaper;
    };
  };

  clan.core.vars.generators.test-vm-secrets = {
    files = {
      "api-key" = {
        secret = true;
        mode = "0400";
      };
      "db-password" = {
        secret = true;
        mode = "0400";
      };
      "jwt-secret" = {
        secret = true;
        mode = "0400";
      };
    };

    runtimeInputs = with pkgs; [
      coreutils
      openssl
    ];

    script = ''
      openssl rand -base64 32 | tr -d '\n' > "$out/api-key"
      openssl rand -base64 32 | tr -d '\n' > "$out/db-password"
      openssl rand -base64 64 | tr -d '\n' > "$out/jwt-secret"

      chmod 400 "$out"/*
    '';
  };

  systemd.services."microvm@test-vm".serviceConfig.LoadCredential = [
    "host-api-key:${config.clan.core.vars.generators.test-vm-secrets.files."api-key".path}"
    "host-db-password:${config.clan.core.vars.generators.test-vm-secrets.files."db-password".path}"
    "host-jwt-secret:${config.clan.core.vars.generators.test-vm-secrets.files."jwt-secret".path}"
  ];

  microvm.vms = {
    test-vm = {
      # Auto-start the VM
      autostart = true;

      # VM configuration
      config =
        {
          pkgs,
          lib,
          config,
          ...
        }:
        {
          imports = [ inputs.microvm.nixosModules.microvm ];

          # Basic microvm configuration
          microvm = {
            hypervisor = "cloud-hypervisor";
            vcpu = 2;
            mem = 1024;

            # Share host's /nix/store (read-only)
            shares = [
              {
                tag = "ro-store";
                source = "/nix/store";
                mountPoint = "/nix/.ro-store";
                proto = "virtiofs";
              }
            ];

            # Network configuration
            interfaces = [
              {
                type = "tap";
                id = "vm-test";
                mac = "02:00:00:01:01:01";
              }
            ];

            # Enable vsock for systemd notification
            vsock.cid = 3;

            binScripts.microvm-run = lib.mkForce (
              let
                microvmCfg = config.microvm;
              in
              ''
                set -eou pipefail

                echo "╔══════════════════════════════════════════════════════════╗"
                echo "║  MicroVM: test-vm"
                echo "║  Loading Runtime Secrets via systemd LoadCredential"
                echo "╚══════════════════════════════════════════════════════════╝"

                # Read secrets from systemd credentials directory
                if [ -n "''${CREDENTIALS_DIRECTORY:-}" ]; then
                  if [ -f "$CREDENTIALS_DIRECTORY/host-api-key" ]; then
                    API_KEY=$(cat "$CREDENTIALS_DIRECTORY/host-api-key" | tr -d '\n')
                    echo "✓ Loaded API_KEY from credentials"
                  else
                    echo "❌ ERROR: host-api-key not found in credentials directory"
                    exit 1
                  fi

                  if [ -f "$CREDENTIALS_DIRECTORY/host-db-password" ]; then
                    DB_PASSWORD=$(cat "$CREDENTIALS_DIRECTORY/host-db-password" | tr -d '\n')
                    echo "✓ Loaded DB_PASSWORD from credentials"
                  else
                    echo "❌ ERROR: host-db-password not found in credentials directory"
                    exit 1
                  fi

                  if [ -f "$CREDENTIALS_DIRECTORY/host-jwt-secret" ]; then
                    JWT_SECRET=$(cat "$CREDENTIALS_DIRECTORY/host-jwt-secret" | tr -d '\n')
                    echo "✓ Loaded JWT_SECRET from credentials"
                  else
                    echo "❌ ERROR: host-jwt-secret not found in credentials directory"
                    exit 1
                  fi
                else
                  echo "❌ ERROR: CREDENTIALS_DIRECTORY not set"
                  exit 1
                fi

                # Build OEM strings with runtime secrets
                RUNTIME_OEM_STRINGS="io.systemd.credential:API_KEY=$API_KEY"
                RUNTIME_OEM_STRINGS="$RUNTIME_OEM_STRINGS,io.systemd.credential:DB_PASSWORD=$DB_PASSWORD"
                RUNTIME_OEM_STRINGS="$RUNTIME_OEM_STRINGS,io.systemd.credential:JWT_SECRET=$JWT_SECRET"
                RUNTIME_OEM_STRINGS="$RUNTIME_OEM_STRINGS,io.systemd.credential:ENVIRONMENT=test"
                RUNTIME_OEM_STRINGS="$RUNTIME_OEM_STRINGS,io.systemd.credential:CLUSTER=britton-desktop"
                RUNTIME_OEM_STRINGS="$RUNTIME_OEM_STRINGS,io.systemd.credential:vmm.notify_socket=vsock-stream:2:8888"

                echo "✓ Runtime secrets loaded and OEM strings prepared"
                echo "══════════════════════════════════════════════════════════"

                # Run original preStart
                ${microvmCfg.preStart}

                # Cleanup sockets
                rm -f test-vm.sock notify.vsock notify.vsock_8888 || true

                # Start socat for vsock notify
                if [ -n "''${NOTIFY_SOCKET:-}" ]; then
                  ${pkgs.socat}/bin/socat -T2 UNIX-LISTEN:notify.vsock_8888,fork UNIX-SENDTO:$NOTIFY_SOCKET &
                fi

                # Execute cloud-hypervisor with runtime-injected secrets
                exec ${lib.optionalString microvmCfg.prettyProcnames ''-a "microvm@test-vm"''} \
                  ${pkgs.cloud-hypervisor}/bin/cloud-hypervisor \
                  --cpus boot=2 \
                  --watchdog \
                  --kernel ${microvmCfg.kernel.dev}/vmlinux \
                  --initramfs ${microvmCfg.initrdPath} \
                  --cmdline "earlyprintk=ttyS0 console=ttyS0 reboot=t panic=-1 ${toString microvmCfg.kernelParams}" \
                  --seccomp true \
                  --memory mergeable=on,shared=on,size=1024M \
                  --platform "oem_strings=[$RUNTIME_OEM_STRINGS]" \
                  --console null \
                  --serial tty \
                  --vsock cid=3,socket=notify.vsock \
                  --fs socket=test-vm-virtiofs-ro-store.sock,tag=ro-store \
                  --api-socket test-vm.sock \
                  --net mac=02:00:00:01:01:01,num_queues=4,tap=vm-test
              ''
            );
          };

          # Basic NixOS configuration for the guest
          networking = {
            hostName = "test-vm";
            interfaces.eth0.useDHCP = lib.mkDefault true;
            firewall.allowedTCPPorts = [ 22 ];
          };
          system.stateVersion = "24.05";

          # Enable SSH for remote access
          services.openssh = {
            enable = true;
            settings = {
              PermitRootLogin = "yes";
              PasswordAuthentication = true; # Enabled for testing
            };
          };

          # Set root password for SSH access (testing only!)
          users.users.root.initialPassword = "test";

          # Auto-login for easy testing
          services.getty.autologinUser = "root";

          # Test service that consumes the OEM string credentials INCLUDING RUNTIME SECRETS
          # This writes to the serial console so we can see output in journalctl
          systemd.services.demo-oem-credentials = {
            description = "Demo service showing OEM string credentials with runtime secrets";
            wantedBy = [ "multi-user.target" ];
            after = [ "network.target" ];

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              StandardOutput = "journal+console";
              StandardError = "journal+console";
              LoadCredential = [
                "environment:ENVIRONMENT"
                "cluster:CLUSTER"
                "api-key:API_KEY"
                "db-password:DB_PASSWORD"
                "jwt-secret:JWT_SECRET"
              ];
            };

            script = ''
              echo "╔═══════════════════════════════════════════════════════════════╗"
              echo "║  OEM String Credentials with Runtime Secrets (test-vm)      ║"
              echo "╚═══════════════════════════════════════════════════════════════╝"
              echo ""
              echo "✓ systemd credentials available:"
              ${pkgs.systemd}/bin/systemd-creds --system list | grep -E "API_KEY|DB_PASSWORD|JWT_SECRET|ENVIRONMENT|CLUSTER" || echo "  (none found)"
              echo ""
              echo "Static Configuration:"
              echo "  ENVIRONMENT = $(cat $CREDENTIALS_DIRECTORY/environment 2>/dev/null || echo 'N/A')"
              echo "  CLUSTER     = $(cat $CREDENTIALS_DIRECTORY/cluster 2>/dev/null || echo 'N/A')"
              echo ""
              echo "Runtime Secrets (length check):"
              echo "  API_KEY     = $(wc -c < $CREDENTIALS_DIRECTORY/api-key 2>/dev/null || echo '0') bytes"
              echo "  DB_PASSWORD = $(wc -c < $CREDENTIALS_DIRECTORY/db-password 2>/dev/null || echo '0') bytes"
              echo "  JWT_SECRET  = $(wc -c < $CREDENTIALS_DIRECTORY/jwt-secret 2>/dev/null || echo '0') bytes"
              echo ""
              if [ $(wc -c < $CREDENTIALS_DIRECTORY/api-key 2>/dev/null || echo '0') -gt 10 ]; then
                echo "✓ Runtime secrets successfully loaded from HOST clan vars via OEM strings!"
              else
                echo "⚠️  Runtime secrets not loaded - generate with: clan vars generate britton-desktop"
              fi
              echo ""
              echo "✓ OEM string credentials (static + runtime) successfully loaded via SMBIOS Type 11"
              echo "══════════════════════════════════════════════════════════════════"
            '';
          };

          # Minimal package set
          environment.systemPackages = with pkgs; [
            vim
            htop
          ];
        };
    };
  };

  services = {

    gnome.gnome-keyring.enable = true;

    # Keyd for dual-function keys (Caps Lock = Esc on tap, Ctrl on hold)
    keyd = {
      enable = true;
      keyboards = {
        default = {
          ids = [ "*" ];
          settings = {
            main = {
              capslock = "overload(control, esc)";
            };
          };
        };
      };
    };

    printing.enable = true;

    pulseaudio.enable = false;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
          user = "greeter";
        };
      };
    };

  };

  security = {
    rtkit.enable = true;
    pam.services = {
      login.enableGnomeKeyring = true;
      greetd.enableGnomeKeyring = true;
      sudo.fprintAuth = false;
      hyprlock = { };
    };
  };
}
