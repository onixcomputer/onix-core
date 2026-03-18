{ lib, ... }:
let
  inherit (lib)
    mkOption
    mkIf
    mkMerge
    ;
  inherit (lib.types)
    str
    port
    bool
    nullOr
    listOf
    ;
in
{
  _class = "clan.service";
  manifest = {
    name = "clankers";
    readme = "Clankers coding agent daemon and router services";
  };

  roles = {
    # The daemon hosts agent sessions accessible via iroh QUIC.
    daemon = {
      description = "Clankers daemon — persistent agent sessions over iroh QUIC";
      interface = {
        options = {
          user = mkOption {
            type = str;
            default = "brittonr";
            description = "User to run the daemon as";
          };

          allowAll = mkOption {
            type = bool;
            default = false;
            description = "Skip token/ACL checks (development mode)";
          };

          heartbeat = mkOption {
            type = lib.types.int;
            default = 30;
            description = "Heartbeat interval in seconds (0 to disable)";
          };

          extraArgs = mkOption {
            type = listOf str;
            default = [ ];
            description = "Extra arguments passed to `clankers daemon start`";
          };
        };
      };

      perInstance =
        { settings, ... }:
        {
          nixosModule =
            { pkgs, inputs, ... }:
            let
              rustPkgs = import inputs.nixpkgs {
                inherit (pkgs) system;
                overlays = [ (import inputs.rust-overlay) ];
              };
              nightlyToolchain = rustPkgs.rust-bin.nightly.latest.default.override {
                extensions = [ "rust-src" ];
              };
              clankersPkg = pkgs.callPackage "${inputs.self}/pkgs/clankers" {
                rustc = nightlyToolchain;
                cargo = nightlyToolchain;
              };
              inherit (settings)
                user
                allowAll
                heartbeat
                extraArgs
                ;
              args =
                [ "--heartbeat" (toString heartbeat) ]
                ++ lib.optionals allowAll [ "--allow-all" ]
                ++ extraArgs;
            in
            {
              systemd.services.clankers-daemon = {
                description = "Clankers agent daemon";
                after = [
                  "network-online.target"
                ];
                wants = [ "network-online.target" ];
                wantedBy = [ "multi-user.target" ];

                serviceConfig = {
                  Type = "simple";
                  User = user;
                  ExecStart = "${clankersPkg}/bin/clankers daemon start ${lib.concatStringsSep " " args}";
                  Restart = "on-failure";
                  RestartSec = "10s";

                  # Hardening
                  NoNewPrivileges = true;
                  ProtectSystem = "strict";
                  ProtectHome = "tmpfs";
                  # Bind-mount the user's home for session state + iroh keys
                  BindPaths = [ "/home/${user}" ];
                  PrivateTmp = true;
                  StateDirectory = "clankers";
                };

                environment = {
                  HOME = "/home/${user}";
                  RUST_LOG = "info";
                };
              };
            };
        };
    };

    # The router proxies LLM requests across providers with failover.
    router = {
      description = "Clanker-router — multi-provider LLM proxy with failover and caching";
      interface = {
        options = {
          user = mkOption {
            type = str;
            default = "brittonr";
            description = "User to run the router as";
          };

          listenAddr = mkOption {
            type = str;
            default = "127.0.0.1";
            description = "Address to bind the HTTP proxy";
          };

          listenPort = mkOption {
            type = port;
            default = 4000;
            description = "Port for the OpenAI-compatible HTTP proxy";
          };

          enableIroh = mkOption {
            type = bool;
            default = false;
            description = "Expose the router over iroh QUIC tunnel";
          };

          configFile = mkOption {
            type = nullOr str;
            default = null;
            description = "Path to router config file (uses default if null)";
          };
        };
      };

      perInstance =
        { settings, ... }:
        {
          nixosModule =
            { pkgs, inputs, ... }:
            let
              rustPkgs = import inputs.nixpkgs {
                inherit (pkgs) system;
                overlays = [ (import inputs.rust-overlay) ];
              };
              nightlyToolchain = rustPkgs.rust-bin.nightly.latest.default.override {
                extensions = [ "rust-src" ];
              };
              clankersPkg = pkgs.callPackage "${inputs.self}/pkgs/clankers" {
                rustc = nightlyToolchain;
                cargo = nightlyToolchain;
              };
              inherit (settings)
                user
                listenAddr
                listenPort
                enableIroh
                configFile
                ;
            in
            {
              systemd.services.clanker-router = {
                description = "Clanker-router LLM proxy";
                after = [
                  "network-online.target"
                ];
                wants = [ "network-online.target" ];
                wantedBy = [ "multi-user.target" ];

                serviceConfig = {
                  Type = "simple";
                  User = user;
                  ExecStart = "${clankersPkg}/bin/clankers router start";
                  Restart = "on-failure";
                  RestartSec = "10s";

                  # Hardening
                  NoNewPrivileges = true;
                  ProtectSystem = "strict";
                  ProtectHome = "tmpfs";
                  BindPaths = [ "/home/${user}" ];
                  PrivateTmp = true;
                  StateDirectory = "clanker-router";
                };

                environment = mkMerge [
                  {
                    HOME = "/home/${user}";
                    RUST_LOG = "info";
                    CLANKER_ROUTER_LISTEN = "${listenAddr}:${toString listenPort}";
                  }
                  (mkIf enableIroh { CLANKER_ROUTER_IROH = "1"; })
                  (mkIf (configFile != null) { CLANKER_ROUTER_CONFIG = configFile; })
                ];
              };

              networking.firewall.allowedTCPPorts = [ listenPort ];
            };
        };
    };
  };
}
