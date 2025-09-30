{ lib, ... }:
let
  inherit (lib)
    mkOption
    mkIf
    mkMerge
    ;
  inherit (lib.types)
    str
    int
    bool
    port
    nullOr
    listOf
    attrsOf
    submodule
    enum
    anything
    ;
in
{
  _class = "clan.service";
  manifest = {
    name = "microvm";
    description = "Lightweight virtual machines using microvm.nix";
    categories = [
      "Virtualization"
      "Infrastructure"
    ];
  };

  roles = {
    server = {
      interface = {
        # Freeform type allows passing any additional microvm settings
        freeformType = attrsOf anything;

        options = {
          # Core VM Configuration
          vmName = mkOption {
            type = str;
            description = "Name of the microVM instance";
            example = "test-vm";
          };

          autostart = mkOption {
            type = bool;
            default = true;
            description = "Whether to automatically start the microVM on boot";
          };

          hypervisor = mkOption {
            type = enum [
              "cloud-hypervisor"
              "qemu"
              "firecracker"
              "crosvm"
              "kvmtool"
              "stratovirt"
            ];
            default = "cloud-hypervisor";
            description = "The hypervisor backend to use";
          };

          # Resource Allocation
          vcpu = mkOption {
            type = int;
            default = 2;
            description = "Number of virtual CPUs to allocate";
          };

          mem = mkOption {
            type = int;
            default = 1024;
            description = "Memory allocation in MB";
          };

          # Network Configuration
          interfaces = mkOption {
            type = listOf (attrsOf anything);
            default = [ ];
            description = "Network interface configurations";
            example = [
              {
                type = "tap";
                id = "vm-test";
                mac = "02:00:00:01:01:01";
              }
            ];
          };

          vsockCid = mkOption {
            type = nullOr int;
            default = null;
            description = "VSOCK CID for host-guest communication (null to disable, 3+ to enable)";
          };

          # Storage & Shares
          shares = mkOption {
            type = listOf (attrsOf anything);
            default = [
              {
                tag = "ro-store";
                source = "/nix/store";
                mountPoint = "/nix/.ro-store";
                proto = "virtiofs";
              }
            ];
            description = "Shared filesystem mounts from host to guest";
          };

          volumes = mkOption {
            type = listOf (attrsOf anything);
            default = [ ];
            description = "Additional disk volumes to attach";
          };

          # Security & Credentials
          credentialPrefix = mkOption {
            type = str;
            default = "HOST-";
            description = "Prefix for credential names when passing from host to guest via OEM strings";
          };

          credentials = mkOption {
            type = attrsOf (submodule {
              options = {
                source = mkOption {
                  type = str;
                  description = "Path to the credential file on the host";
                };
                destination = mkOption {
                  type = str;
                  default = "";
                  description = "Name of the credential in the guest (without prefix)";
                };
              };
            });
            default = { };
            description = "Credentials to pass from host to guest";
            example = {
              api-key = {
                source = "/run/secrets/api-key";
                destination = "API-KEY";
              };
            };
          };

          staticOemStrings = mkOption {
            type = listOf str;
            default = [ ];
            description = "Static OEM strings to inject (non-secret configuration)";
            example = [
              "io.systemd.credential:ENVIRONMENT=production"
              "io.systemd.credential:CLUSTER=main"
            ];
          };

          # Service Hardening
          serviceHardening = mkOption {
            type = submodule {
              options = {
                enable = mkOption {
                  type = bool;
                  default = true;
                  description = "Enable systemd service hardening for the microVM";
                };

                protectProc = mkOption {
                  type = enum [
                    "default"
                    "invisible"
                    "noaccess"
                  ];
                  default = "invisible";
                  description = "Process information visibility";
                };

                procSubset = mkOption {
                  type = enum [
                    "all"
                    "pid"
                  ];
                  default = "pid";
                  description = "Process subset exposed in /proc";
                };

                protectHome = mkOption {
                  type = bool;
                  default = true;
                  description = "Protect home directories from the microVM service";
                };

                privateDevices = mkOption {
                  type = bool;
                  default = false; # Required false for VMs
                  description = "Use private /dev (must be false for VMs)";
                };

                restrictAddressFamilies = mkOption {
                  type = listOf str;
                  default = [
                    "AF_UNIX"
                    "AF_VSOCK"
                    "AF_INET"
                    "AF_INET6"
                  ];
                  description = "Allowed address families";
                };

                systemCallFilter = mkOption {
                  type = listOf str;
                  default = [
                    "@system-service"
                    "~@privileged"
                    "@resources"
                    "@kvm"
                  ];
                  description = "System call filter rules";
                };
              };
            };
            default = { };
            description = "Systemd service hardening options";
          };

          # Guest Configuration
          guestModules = mkOption {
            type = listOf anything;
            default = [ ];
            description = "Additional NixOS modules to include in the guest configuration";
          };

          guestHostname = mkOption {
            type = nullOr str;
            default = null;
            description = "Hostname for the guest (defaults to vmName if not set)";
          };

          guestStateVersion = mkOption {
            type = str;
            default = "24.05";
            description = "NixOS state version for the guest";
          };

          # SSH Configuration for Guest
          enableSsh = mkOption {
            type = bool;
            default = true;
            description = "Enable SSH server in the guest";
          };

          sshPort = mkOption {
            type = port;
            default = 22;
            description = "SSH port in the guest";
          };

          rootPassword = mkOption {
            type = nullOr str;
            default = null;
            description = "Root password for the guest (null for no password)";
          };

          authorizedKeys = mkOption {
            type = listOf str;
            default = [ ];
            description = "SSH authorized keys for root user in guest";
          };

          # Additional Guest Services
          guestPackages = mkOption {
            type = listOf anything;
            default = [ ];
            description = "Additional packages to install in the guest";
          };

          firewallPorts = mkOption {
            type = listOf port;
            default = [ ];
            description = "Additional TCP ports to open in the guest firewall";
          };
        };
      };

      perInstance =
        { instanceName, extendSettings, ... }:
        {
          nixosModule =
            { config, pkgs, inputs, ... }:
            let
              settings = extendSettings { };

              # Extract known options from freeform settings
              vmName = settings.vmName or instanceName;
              guestHostname = if settings.guestHostname != null then settings.guestHostname else vmName;

              # Build credential file mappings for LoadCredential
              credentialLoadSpecs = lib.mapAttrsToList (
                name: cfg:
                let
                  destName = if cfg.destination != "" then cfg.destination else name;
                  prefixedName = "${settings.credentialPrefix}${destName}";
                  # Use the clan vars generator path
                  sourcePath = config.clan.core.vars.generators."${instanceName}-secrets".files."${name}".path;
                in
                "${prefixedName}:${sourcePath}"
              ) settings.credentials;

              # Build credential file specs for microvm
              credentialFiles = lib.mapAttrs' (
                name: cfg:
                let
                  destName = if cfg.destination != "" then cfg.destination else name;
                  prefixedName = "${settings.credentialPrefix}${destName}";
                in
                lib.nameValuePair prefixedName { }
              ) settings.credentials;

              # Extract microvm-specific settings
              microvmSettings = removeAttrs settings [
                "vmName"
                "autostart"
                "guestHostname"
                "guestStateVersion"
                "guestModules"
                "guestPackages"
                "enableSsh"
                "sshPort"
                "rootPassword"
                "authorizedKeys"
                "firewallPorts"
                "serviceHardening"
                "credentials"
                "credentialPrefix"
                "staticOemStrings"
                "vsockCid"
                "hypervisor"
                "vcpu"
                "mem"
                "shares"
                "volumes"
                "interfaces"
                "enableDemoCredentialService"
              ];

              # Build the complete guest configuration
              guestConfig = {
                imports = [ inputs.microvm.nixosModules.microvm ] ++ settings.guestModules;

                # Basic microvm configuration
                microvm = mkMerge [
                  microvmSettings
                  {
                    hypervisor = settings.hypervisor;
                    vcpu = settings.vcpu;
                    mem = settings.mem;

                    shares = settings.shares;
                    volumes = settings.volumes;
                    interfaces = settings.interfaces;

                    vsock = mkIf (settings.vsockCid != null) {
                      cid = settings.vsockCid;
                    };

                    # Runtime credentials from host
                    credentialFiles = credentialFiles;

                    # Platform-specific settings
                    ${settings.hypervisor} = mkIf (settings.hypervisor == "cloud-hypervisor") {
                      platformOEMStrings = settings.staticOemStrings;
                    };
                  }
                ];

                # Basic NixOS configuration for the guest
                networking = {
                  hostName = guestHostname;
                  firewall.allowedTCPPorts =
                    (if settings.enableSsh then [ settings.sshPort ] else [ ]) ++ settings.firewallPorts;
                };

                system.stateVersion = settings.guestStateVersion;

                # SSH configuration
                services.openssh = mkIf settings.enableSsh {
                  enable = true;
                  ports = [ settings.sshPort ];
                  settings = {
                    PermitRootLogin =
                      if settings.rootPassword != null || settings.authorizedKeys != [ ] then
                        "yes"
                      else
                        "prohibit-password";
                    PasswordAuthentication = settings.rootPassword != null;
                  };
                };

                # Root user configuration
                users.users.root = mkMerge [
                  (mkIf (settings.rootPassword != null) {
                    initialPassword = settings.rootPassword;
                  })
                  (mkIf (settings.authorizedKeys != [ ]) {
                    openssh.authorizedKeys.keys = settings.authorizedKeys;
                  })
                ];

                # Additional packages
                environment.systemPackages = settings.guestPackages;

                # Auto-login for testing if password is set
                services.getty = mkIf (settings.rootPassword != null) {
                  autologinUser = "root";
                };

                # Demo credential logging service (for test VMs)
                systemd.services.demo-credentials = mkIf (settings.enableDemoCredentialService or false) {
                  description = "Demo service that logs test credentials to journal";
                  wantedBy = [ "multi-user.target" ];
                  after = [ "network.target" ];

                  serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                    StandardOutput = "journal+console";
                    StandardError = "journal+console";
                    LoadCredential =
                      (if settings ? staticOemStrings then
                        lib.map (str:
                          let
                            parts = lib.splitString ":" (lib.removePrefix "io.systemd.credential:" str);
                            credName = lib.head parts;
                          in
                          "${lib.toLower credName}:${credName}"
                        ) (lib.filter (lib.hasPrefix "io.systemd.credential:") settings.staticOemStrings)
                      else [])
                      ++
                      lib.mapAttrsToList (name: cfg:
                        let
                          destName = if cfg.destination != "" then cfg.destination else name;
                        in
                        "${name}:${settings.credentialPrefix}${destName}"
                      ) (settings.credentials or {});
                  };

                  script = ''
                    echo "=========================================="
                    echo "CREDENTIAL TEST - SHOWING RAW VALUES"
                    echo "=========================================="
                    echo ""

                    echo "All available credentials:"
                    for cred in "$CREDENTIALS_DIRECTORY"/*; do
                      if [ -f "$cred" ]; then
                        name=$(basename "$cred")
                        value=$(cat "$cred")
                        echo "  $name = '$value'"
                      fi
                    done

                    echo ""
                    echo "=========================================="
                    echo "Credential directory contents:"
                    ls -la "$CREDENTIALS_DIRECTORY/" 2>&1 || echo "  Directory not found"
                    echo "=========================================="
                  '';
                };
              };
            in
            {
              # Import microvm host module
              imports = [ inputs.microvm.nixosModules.host ];

              # Configure the microVM
              microvm.vms.${vmName} = {
                inherit (settings) autostart;
                config = guestConfig;
              };

              # Configure systemd service with hardening and credentials
              systemd.services."microvm@${vmName}" = {
                serviceConfig = mkMerge [
                  # Load credentials from host
                  (mkIf (credentialLoadSpecs != [ ]) {
                    LoadCredential = credentialLoadSpecs;
                  })

                  # Apply service hardening if enabled
                  (mkIf settings.serviceHardening.enable {
                    ProtectProc = settings.serviceHardening.protectProc;
                    ProcSubset = settings.serviceHardening.procSubset;
                    ProtectKernelTunables = true;
                    ProtectControlGroups = true;
                    ProtectHome = settings.serviceHardening.protectHome;
                    PrivateDevices = settings.serviceHardening.privateDevices;
                    RestrictAddressFamilies = settings.serviceHardening.restrictAddressFamilies;
                    SystemCallFilter = settings.serviceHardening.systemCallFilter;

                    # Standard security options
                    NoNewPrivileges = true;
                    RestrictSUIDSGID = true;
                    RemoveIPC = true;
                    ProtectKernelModules = true;
                    RestrictRealtime = true;
                    RestrictNamespaces = true;
                    LockPersonality = true;
                    MemoryDenyWriteExecute = false; # Must be false for VMs

                    # Logging
                    StandardOutput = "journal";
                    StandardError = "journal";
                  })
                ];
              };

              # Generate secrets if using clan vars pattern
              clan.core.vars.generators."${instanceName}-secrets" = mkIf (settings.credentials != { }) {
                files = lib.mapAttrs (_name: _: {
                  secret = true;
                  mode = "0400";
                }) settings.credentials;

                runtimeInputs = with pkgs; [
                  coreutils
                  openssl
                ];

                script = ''
                  # Generate random secrets for each credential
                  ${lib.concatStringsSep "\n" (
                    lib.mapAttrsToList (name: _: ''
                      openssl rand -base64 32 | tr -d '\n' > "$out/${name}"
                      chmod 400 "$out/${name}"
                    '') settings.credentials
                  )}
                '';
              };
            };
        };
    };
  };

  # No perMachine configuration needed for microvm
  perMachine = _: {
    nixosModule = _: { };
  };
}
