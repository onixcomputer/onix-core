{ lib, ... }:
let
  inherit (lib) mkOption;
  inherit (lib.types)
    bool
    str
    nullOr
    listOf
    ;
in
{
  _class = "clan.service";
  manifest.name = "tailscale";
  # Define available roles
  roles = {
    # Standard node that joins the tailnet
    peer = {
      interface = {
        options = {
          enableSSH = mkOption {
            type = bool;
            default = false;
            description = "Whether to enable SSH server through Tailscale";
          };
          autoconnect = mkOption {
            type = bool;
            default = true;
            description = "Whether to auto-connect to the tailnet";
          };
          authKeyFile = mkOption {
            type = nullOr str;
            default = null;
            description = "Path to the auth key file to use for automatic authentication";
          };
          exitNode = mkOption {
            type = bool;
            default = false;
            description = "Whether to advertise this machine as an exit node";
          };
          extraFlags = mkOption {
            type = listOf str;
            default = [ ];
            description = "Additional flags to pass to the Tailscale daemon";
          };
        };
      };
      perInstance =
        { extendSettings, ... }:
        {
          nixosModule =
            { config, ... }:
            let
              localSettings = extendSettings {
                authKeyFile = lib.mkDefault config.clan.core.vars.generators.tailscale.files.auth_key.path;
              };
            in
            {
              services.tailscale = {
                enable = true;
                useRoutingFeatures = "both";
                inherit (localSettings) authKeyFile;
                extraUpFlags =
                  (lib.optional localSettings.autoconnect "--ssh=${
                    if localSettings.enableSSH then "true" else "false"
                  }")
                  ++ (lib.optional localSettings.exitNode "--advertise-exit-node")
                  ++ localSettings.extraFlags;
              };

              # Open firewall ports for Tailscale
              networking.firewall = {
                # Enable checksum offload as recommended by Tailscale
                checkReversePath = "loose";
                trustedInterfaces = [ "tailscale0" ];
                allowedUDPPorts = [ 41641 ]; # Tailscale UDP port
              };

              # Configure NAT for exit nodes
              networking.nat = lib.mkIf localSettings.exitNode {
                enable = true;
                # If already configured, preserve the existing settings
                externalInterface = lib.mkDefault (lib.mkIf (config.networking.interfaces ? "eth0") "eth0");
                internalInterfaces = [ "tailscale0" ];
              };
            };
        };
    };
  };
  # Common configuration for all machines in this service
  perMachine = _: {
    nixosModule =
      { pkgs, ... }:
      {
        # Install Tailscale package on all machines
        environment.systemPackages = [ pkgs.tailscale ];

        # Create vars generator for Tailscale auth keys
        clan.core.vars.generators.tailscale = {
          files.auth_key = { };
          runtimeInputs = [ pkgs.coreutils ];
          prompts.auth_key = {
            description = "Tailscale auth key";
            type = "hidden";
            persist = true;
          };
          script = ''
            cat "$prompts"/auth_key > "$out"/auth_key
          '';
        };

        # Make the Tailscale service persistent
        systemd.services.tailscaled.wantedBy = [ "multi-user.target" ];
      };
  };
}
