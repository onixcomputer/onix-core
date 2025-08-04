{ lib, ... }:
let
  inherit (lib)
    mkOption
    mkDefault
    mkEnableOption
    mkIf
    ;
  inherit (lib.types)
    str
    int
    bool
    enum
    listOf
    attrsOf
    anything
    ;
in
{
  _class = "clan.service";
  manifest.name = "pixiecore";

  roles = {
    server = {
      interface = {
        # Allow freeform configuration
        freeformType = attrsOf anything;

        options = {
          enable = mkEnableOption "Enable Pixiecore PXE boot server";

          listenAddr = mkOption {
            type = str;
            default = "0.0.0.0";
            description = "Address to listen on";
          };

          port = mkOption {
            type = int;
            default = 80;
            description = "Port to serve HTTP on";
          };

          dhcpNoBind = mkOption {
            type = bool;
            default = false;
            description = "Whether to avoid binding to the DHCP port";
          };

          # Deprecated options kept for compatibility
          mode = mkOption {
            type = enum [
              "quick"
              "api"
              "boot"
            ];
            default = "api";
            description = "DEPRECATED: Mode is always 'boot' now. This option is ignored.";
          };

          apiServer = mkOption {
            type = str;
            default = "http://localhost:8080";
            description = "DEPRECATED: API server is no longer used. This option is ignored.";
          };

          extraOptions = mkOption {
            type = listOf str;
            default = [ ];
            description = "Extra command line options for pixiecore";
          };

          # Deprecated boot mode options
          kernel = mkOption {
            type = str;
            default = "";
            description = "DEPRECATED: Custom netboot is always built. This option is ignored.";
          };

          initrd = mkOption {
            type = listOf str;
            default = [ ];
            description = "DEPRECATED: Custom netboot is always built. This option is ignored.";
          };

          cmdline = mkOption {
            type = str;
            default = "";
            description = "DEPRECATED: Kernel cmdline is auto-generated. Use netbootConfig.boot.kernelParams instead.";
          };

          sshAuthorizedKeys = mkOption {
            type = listOf str;
            default = [ ];
            description = "SSH authorized keys to embed in netboot image";
          };

          # Freeform netboot configuration options
          netbootPackages = mkOption {
            type = listOf anything;
            default = [ ];
            description = "Additional packages to include in the netboot image";
            example = [
              "pkgs.git"
              "pkgs.nmap"
            ];
          };

          netbootModules = mkOption {
            type = listOf anything;
            default = [ ];
            description = "Additional NixOS modules to include in the netboot configuration";
          };

          netbootConfig = mkOption {
            type = attrsOf anything;
            default = { };
            description = "Additional NixOS configuration to merge into the netboot system";
            example = {
              networking.hostName = "netboot";
              services.nginx.enable = true;
            };
          };
        };
      };

      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            {
              config,
              pkgs,
              inputs,
              ...
            }:
            let
              cfg = extendSettings { };

              # Extract known pixiecore options

              # Separate freeform netboot configuration
              netbootPackages = cfg.netbootPackages or [ ];
              netbootModules = cfg.netbootModules or [ ];
              netbootConfig = cfg.netbootConfig or { };

              # Always build custom netboot
              customNetboot =
                let
                  sys = inputs.nixpkgs.lib.nixosSystem {
                    inherit (pkgs) system;
                    modules = [
                      (
                        {
                          config,
                          pkgs,
                          lib,
                          modulesPath,
                          ...
                        }:
                        {
                          imports = [ (modulesPath + "/installer/netboot/netboot-minimal.nix") ] ++ netbootModules;
                          config = lib.mkMerge [
                            {
                              services.openssh = {
                                enable = true;
                                openFirewall = true;
                                settings = {
                                  PermitRootLogin = "yes";
                                  PasswordAuthentication = false;
                                  KbdInteractiveAuthentication = false;
                                };
                              };

                              users.users.root.openssh.authorizedKeys.keys = cfg.sshAuthorizedKeys;

                              # Ensure networking works
                              networking.useDHCP = lib.mkDefault true;
                              networking.firewall.enable = false;

                              # Add useful packages
                              environment.systemPackages =
                                with pkgs;
                                [
                                  vim
                                  curl
                                  wget
                                  htop
                                  tmux
                                  nixos-facter
                                ]
                                ++ netbootPackages;
                            }
                            # Merge in any additional netboot configuration
                            netbootConfig
                          ];
                        }
                      )
                    ];
                  };
                in
                sys.config.system.build;
            in
            mkIf cfg.enable {
              # Create pixiecore user
              users.users.pixiecore = {
                isSystemUser = true;
                group = "pixiecore";
                description = "Pixiecore PXE boot server";
              };

              users.groups.pixiecore = { };

              # Main pixiecore service
              systemd.services.pixiecore = {
                description = "Pixiecore network boot server";
                after = [ "network.target" ];
                wantedBy = [ "multi-user.target" ];

                serviceConfig = {
                  ExecStart =
                    let
                      # Always use boot mode with custom netboot
                      actualMode = "boot";
                      actualKernel = "${customNetboot.kernel}/bzImage";
                      actualInitrd = [ "${customNetboot.netbootRamdisk}/initrd" ];
                      actualCmdline = "init=${customNetboot.toplevel}/init loglevel=4";

                      baseCmd = "${pkgs.pixiecore}/bin/pixiecore ${actualMode}";
                      modeArgs = "${actualKernel} ${lib.concatStringsSep " " actualInitrd}${
                        lib.optionalString (actualCmdline != "") " --cmdline \"${actualCmdline}\""
                      }";
                    in
                    "${baseCmd} ${modeArgs} --listen-addr ${cfg.listenAddr} --port ${toString cfg.port} ${lib.optionalString cfg.dhcpNoBind "--dhcp-no-bind"} ${lib.concatStringsSep " " cfg.extraOptions}";
                  Restart = "always";
                  User = "root"; # Needs root for DHCP
                  AmbientCapabilities = [
                    "CAP_NET_BIND_SERVICE"
                    "CAP_NET_RAW"
                  ];
                };
              };

              # Enable required ports in firewall
              networking.firewall = {
                allowedTCPPorts = [ cfg.port ]; # Pixiecore HTTP
                allowedUDPPorts = [
                  67
                  68
                  69
                  4011
                ]; # DHCP, TFTP, PXE
              };
            };
        };
    };
  };
}
