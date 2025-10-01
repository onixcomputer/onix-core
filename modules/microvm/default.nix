_: {
  _class = "clan.service";

  manifest = {
    name = "microvm";
    description = "Lightweight virtual machines using microvm.nix";
    categories = [
      "Virtualization"
      "Infrastructure"
    ];
  };

  roles.server = {
    interface =
      { lib, ... }:
      {
        freeformType = lib.types.attrsOf lib.types.anything;

        options = {
          # Guest Configuration
          guestConfig = lib.mkOption {
            type = lib.types.nullOr lib.types.anything;
            default = null;
            description = "Path to guest configuration file or inline NixOS module";
            example = "./guest-config.nix";
          };

          # Credential Management
          credentials = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = { };
            description = "Credentials to generate and pass to guest (name -> guest environment variable name)";
            example = {
              "api-key" = "API_KEY";
              "db-password" = "DB_PASSWORD";
            };
          };

          # SSH Access
          enableSSH = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable SSH access to guest with host user keys";
          };

          # Service Hardening
          enableHardening = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable systemd service hardening for the microVM service";
          };
        };
      };

    perInstance =
      { instanceName, settings, ... }:
      {
        nixosModule =
          {
            config,
            pkgs,
            inputs,
            lib,
            ...
          }:
          let
            # Extract clan-specific options
            guestConfig = settings.guestConfig or null;
            credentials = settings.credentials or { };
            enableSSH = settings.enableSSH or true;
            enableHardening = settings.enableHardening or true;

            # Remove clan options and host-only options before passing to microvm
            microvmSettings = builtins.removeAttrs settings [
              "guestConfig"
              "credentials"
              "enableSSH"
              "enableHardening"
              "autostart"
              "vmName"
              "vsockCid"
            ];

            # Set sensible defaults for microvm (guest configuration only)
            defaultMicrovmSettings = {
              hypervisor = "cloud-hypervisor";
              vcpu = 2;
              mem = 1024;
              shares = [
                {
                  tag = "ro-store";
                  source = "/nix/store";
                  mountPoint = "/nix/.ro-store";
                  proto = "virtiofs";
                }
              ];
            };

            finalMicrovmSettings = defaultMicrovmSettings // microvmSettings;
            vmName = finalMicrovmSettings.vmName or instanceName;
            generatorName = "microvm-${instanceName}";

            # Build guest configuration
            guestModule =
              if guestConfig != null then
                guestConfig
              else
                # Minimal default guest configuration
                {
                  system.stateVersion = "25.05";
                  nixpkgs.hostPlatform = "x86_64-linux";

                  networking = {
                    hostName = vmName;
                    interfaces.eth0.useDHCP = lib.mkDefault true;
                    firewall.allowedTCPPorts = lib.mkIf enableSSH [ 22 ];
                  };

                  # SSH configuration if enabled
                  services.openssh = lib.mkIf enableSSH {
                    enable = true;
                    settings = {
                      PermitRootLogin = "prohibit-password";
                      PasswordAuthentication = false;
                    };
                  };

                  # Set up credentials from host
                  systemd.services.microvm-credentials = lib.mkIf (credentials != { }) {
                    description = "Load credentials from host for microVM";
                    wantedBy = [ "multi-user.target" ];
                    serviceConfig = {
                      Type = "oneshot";
                      RemainAfterExit = true;
                      LoadCredential = lib.mapAttrsToList (
                        name: _envVar: "${lib.toLower name}:HOST-${lib.toUpper name}"
                      ) credentials;
                    };

                    script = ''
                      # Export credentials as environment variables
                      ${lib.concatStringsSep "\n" (
                        lib.mapAttrsToList (name: envVar: ''
                          if [ -f "$CREDENTIALS_DIRECTORY/${lib.toLower name}" ]; then
                            export ${envVar}="$(cat "$CREDENTIALS_DIRECTORY/${lib.toLower name}")"
                            echo "Loaded credential: ${envVar}"
                          fi
                        '') credentials
                      )}
                    '';
                  };
                };

            # Build credential mappings for systemd LoadCredential
            credentialMappings = lib.mapAttrsToList (
              name: _envVar:
              "HOST-${lib.toUpper name}:${
                config.clan.core.vars.generators."${generatorName}".files."${name}".path
              }"
            ) credentials;

            # Build credential files for microvm
            credentialFiles = lib.mapAttrs' (
              name: _envVar: lib.nameValuePair "HOST-${lib.toUpper name}" { }
            ) credentials;

          in
          {
            imports = [ inputs.microvm.nixosModules.host ];

            # Configure the microVM
            microvm.vms.${vmName} = {
              autostart = settings.autostart or true;
              config = {
                imports = [
                  inputs.microvm.nixosModules.microvm
                  guestModule
                ];

                # Apply microvm configuration
                microvm = finalMicrovmSettings // {
                  # Override with credential files if we have any
                  credentialFiles = lib.mkIf (credentials != { }) credentialFiles;
                  # Handle vsock configuration properly
                  vsock = lib.mkIf (settings ? vsockCid && settings.vsockCid != null) {
                    cid = settings.vsockCid;
                  };
                };
              };
            };

            # Configure systemd service
            systemd.services."microvm@${vmName}" = {
              serviceConfig = lib.mkMerge [
                # Load credentials from host
                (lib.mkIf (credentials != { }) {
                  LoadCredential = credentialMappings;
                })

                # Apply hardening if enabled
                (lib.mkIf enableHardening {
                  # Standard VM-compatible hardening
                  ProtectProc = "invisible";
                  ProcSubset = "pid";
                  ProtectKernelTunables = true;
                  ProtectControlGroups = true;
                  ProtectHome = true;
                  PrivateDevices = false; # Must be false for VMs
                  RestrictAddressFamilies = [
                    "AF_UNIX"
                    "AF_VSOCK"
                    "AF_INET"
                    "AF_INET6"
                  ];
                  SystemCallFilter = [
                    "@system-service"
                    "~@privileged"
                    "@resources"
                  ];
                  NoNewPrivileges = true;
                  RestrictSUIDSGID = true;
                  RemoveIPC = true;
                  ProtectKernelModules = true;
                  RestrictRealtime = true;
                  RestrictNamespaces = true;
                  LockPersonality = true;
                  MemoryDenyWriteExecute = false; # Must be false for VMs
                  StandardOutput = "journal";
                  StandardError = "journal";
                })
              ];
            };

            # Generate credentials using clan vars
            clan.core.vars.generators.${generatorName} = lib.mkIf (credentials != { }) {
              files = lib.mapAttrs (_name: _envVar: {
                secret = true;
                mode = "0400";
              }) credentials;

              runtimeInputs = [ pkgs.openssl ];

              script = ''
                ${lib.concatStringsSep "\n" (
                  lib.mapAttrsToList (name: _envVar: ''
                    openssl rand -base64 32 | tr -d '\n' > "$out/${name}"
                    chmod 400 "$out/${name}"
                  '') credentials
                )}
              '';
            };

          };
      };
  };
}
