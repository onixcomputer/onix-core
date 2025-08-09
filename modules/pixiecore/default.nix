{ lib, ... }:
let
  inherit (lib)
    mkOption
    mkDefault
    mkEnableOption
    mkIf
    mkMerge
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

          mode = mkOption {
            type = enum [
              "quick"
              "api"
              "boot"
            ];
            default = "boot";
            description = "Boot mode: 'boot' serves static kernel/initrd, 'api' queries an API server for dynamic configuration";
          };

          apiServer = mkOption {
            type = str;
            default = "http://localhost:8080";
            description = "API server URL when using API mode";
          };

          extraOptions = mkOption {
            type = listOf str;
            default = [ ];
            description = "Extra command line options for pixiecore";
          };

          sshAuthorizedKeys = mkOption {
            type = listOf str;
            default = [ ];
            description = "SSH authorized keys to embed in netboot image";
          };

          kexecEnabled = mkOption {
            type = bool;
            default = true;
            description = "Include kexec-tools in the netboot image for fast kexec-based provisioning";
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
                              nix = {
                                settings = {
                                  substituters = [
                                    "http://192.168.8.227:5000"
                                    "https://nix-community.cachix.org"
                                    "https://cache.nixos.org/"
                                  ];
                                  trusted-public-keys = [
                                    "harmonia-britton-fw-1754726891:8p0Zry0lnJOoAmNyv3cVSBHENop6DCwm3ymUPf0a0BQ="
                                    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
                                  ];
                                };
                              };

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
                                ++ (if cfg.kexecEnabled then [ kexec-tools ] else [ ])
                                ++ netbootPackages;

                              # Display IP addresses on login
                              systemd.services.show-ip-addresses = {
                                description = "Display IP addresses on console";
                                after = [ "network-online.target" ];
                                wants = [ "network-online.target" ];
                                wantedBy = [ "multi-user.target" ];

                                serviceConfig = {
                                  Type = "oneshot";
                                  RemainAfterExit = true;
                                  StandardOutput = "journal+console";
                                };

                                script = ''
                                  echo "======================================="
                                  echo "Network interfaces and IP addresses:"
                                  echo "======================================="
                                  ${pkgs.iproute2}/bin/ip -a
                                  echo "======================================="
                                '';
                              };
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
            mkMerge [
              # Base configuration
              (mkIf cfg.enable {
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
                        actualMode = cfg.mode;

                        baseCmd = "${pkgs.pixiecore}/bin/pixiecore ${actualMode}";

                        modeArgs =
                          if actualMode == "api" then
                            cfg.apiServer
                          else if actualMode == "boot" then
                            let
                              actualKernel = "${customNetboot.kernel}/bzImage";
                              actualInitrd = [ "${customNetboot.netbootRamdisk}/initrd" ];
                              actualCmdline = "init=${customNetboot.toplevel}/init loglevel=4";
                            in
                            "${actualKernel} ${lib.concatStringsSep " " actualInitrd}${
                              lib.optionalString (actualCmdline != "") " --cmdline \"${actualCmdline}\""
                            }"
                          else
                            ""; # quick mode or other
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
                  allowedTCPPorts = [
                    cfg.port
                  ]
                  ++ (
                    if cfg.mode == "api" then
                      [
                        8080
                        8081
                      ]
                    else
                      [ ]
                  ); # API and file server ports
                  allowedUDPPorts = [
                    67
                    68
                    69
                    4011
                  ]; # DHCP, TFTP, PXE
                };
              })

              # API mode specific configuration
              (mkIf (cfg.enable && cfg.mode == "api") {
                systemd = {
                  services = {
                    pixiecore-api = {
                      description = "Pixiecore API server";
                      after = [ "network.target" ];
                      wantedBy = [ "multi-user.target" ];

                      script =
                        let
                          apiScript = pkgs.writeText "pixiecore-api-server.py" ''
                            import json
                            import http.server
                            import socketserver
                            from urllib.parse import urlparse, parse_qs

                            class PixiecoreAPIHandler(http.server.BaseHTTPRequestHandler):
                                def do_GET(self):
                                    parsed_path = urlparse(self.path)
                                    
                                    if parsed_path.path.startswith('/v1/boot'):
                                        # Handle both /v1/boot?mac=XX and /v1/boot/XX formats
                                        if '/' in parsed_path.path[9:]:  # Check for MAC in path
                                            mac = parsed_path.path.split('/')[-1]
                                        else:
                                            mac_list = parse_qs(parsed_path.query).get('mac', None)
                                            mac = mac_list[0] if mac_list else ""
                                        
                                        # Use the actual IP instead of 0.0.0.0 for client access
                                        server_ip = "${cfg.listenAddr}"
                                        if server_ip == "0.0.0.0":
                                            # Get the IP from the request
                                            server_ip = self.headers.get('Host', '192.168.1.140').split(':')[0]
                                        
                                        # Get kernel params from the built system (empty by default in netboot)
                                        kernel_params = []
                                        
                                        # Build cmdline string
                                        cmdline_parts = []
                                        for param in kernel_params:
                                            if not param.startswith("root="):
                                                cmdline_parts.append(param)
                                        
                                        # Add init parameter
                                        cmdline_parts.append("init=${customNetboot.toplevel}/init")
                                        
                                        # Add any custom kernel params from netbootConfig
                                        if hasattr(config, 'boot') and hasattr(config.boot, 'kernelParams'):
                                            cmdline_parts.extend(${
                                              builtins.toJSON (cfg.netbootConfig.boot.kernelParams or [ ])
                                            })
                                        
                                        cmdline = " ".join(cmdline_parts)
                                        
                                        # Return standard response that pixiecore will convert to iPXE
                                        response = {
                                            "kernel": f"http://{server_ip}:8081/kernel",
                                            "initrd": [f"http://{server_ip}:8081/initrd"],
                                            "cmdline": cmdline
                                        }
                                        
                                        # You can customize response based on MAC address here
                                        # Example:
                                        # if mac == "aa:bb:cc:dd:ee:ff":
                                        #     response["cmdline"] += " custom_param=value"
                                        
                                        self.send_response(200)
                                        self.send_header('Content-Type', 'application/json')
                                        self.end_headers()
                                        self.wfile.write(json.dumps(response).encode())
                                    else:
                                        self.send_error(404)
                                
                                def log_message(self, format, *args):
                                    # Log to systemd journal
                                    print(f"pixiecore-api: {format % args}")

                            PORT = 8080
                            with socketserver.TCPServer(("", PORT), PixiecoreAPIHandler) as httpd:
                                print(f"API server listening on port {PORT}")
                                httpd.serve_forever()
                          '';
                        in
                        ''
                          ${pkgs.python3}/bin/python3 ${apiScript}
                        '';

                      serviceConfig = {
                        Restart = "always";
                        RestartSec = "10s";
                        WorkingDirectory = "/var/lib/pixiecore";
                      };
                    };

                    pixiecore-files = {
                      description = "Pixiecore file server";
                      after = [ "network.target" ];
                      wantedBy = [ "multi-user.target" ];

                      serviceConfig = {
                        ExecStart = "${pkgs.python3}/bin/python3 -m http.server 8081";
                        Restart = "always";
                        RestartSec = "10s";
                        WorkingDirectory = "/var/lib/pixiecore";
                      };
                    };
                  }; # end services

                  tmpfiles.rules = [
                    "d /var/lib/pixiecore 0755 root root -"
                    "L+ /var/lib/pixiecore/kernel - - - - ${customNetboot.kernel}/bzImage"
                    "L+ /var/lib/pixiecore/initrd - - - - ${customNetboot.netbootRamdisk}/initrd"
                  ];
                }; # end systemd
              })
            ];
        };
    };
  };
}
