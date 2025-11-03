_: {
  _class = "clan.service";

  manifest = {
    name = "tailscale";
    description = "Tailscale VPN - Zero-config mesh networking";
    readme = "Tailscale mesh VPN service for secure peer-to-peer networking";
    categories = [
      "Networking"
      "VPN"
    ];
  };

  roles.peer = {
    description = "Tailscale peer that connects to the mesh VPN network";
    interface =
      { lib, ... }:
      {
        freeformType = lib.types.attrsOf lib.types.anything;

        options = {
          enableHostAliases = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Automatically sync Tailscale device names to /etc/hosts";
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
            lib,
            ...
          }:
          let
            generatorName = "tailscale-${instanceName}";

            enableHostAliases = settings.enableHostAliases or true;
            enableSSH = settings.enableSSH or false;
            exitNode = settings.exitNode or false;

            tailscaleSettings = builtins.removeAttrs settings [
              "enableHostAliases"
              "enableSSH"
              "exitNode"
            ];

            extraUpFlags =
              (lib.optional enableSSH "--ssh")
              ++ (lib.optional exitNode "--advertise-exit-node")
              ++ (settings.extraUpFlags or [ ]);

            finalSettings = tailscaleSettings // {
              authKeyFile = lib.mkDefault config.clan.core.vars.generators."${generatorName}".files.auth_key.path;
              inherit extraUpFlags;
            };
          in
          {
            imports = [ ./host-sync.nix ];

            clan.core.vars.generators."${generatorName}" = {
              share = true;
              files.auth_key = { };
              runtimeInputs = [ pkgs.coreutils ];

              prompts.auth_key = {
                description = "Tailscale auth key for instance '${instanceName}'";
                type = "hidden";
                persist = true;
              };

              script = ''
                cat "$prompts"/auth_key > "$out"/auth_key
              '';
            };

            services.tailscale = finalSettings // {
              enable = true;
              useRoutingFeatures = lib.mkDefault "both";
            };

            services.tailscale-host-sync.enable = enableHostAliases;

            # Don't block boot at all - start in background after network is online
            systemd.services.tailscaled-autoconnect = lib.mkIf (finalSettings.autoconnect or false) {
              wantedBy = lib.mkForce [ "multi-user.target" ];
              wants = [ "network-online.target" ];
              after = [ "network-online.target" ];
              serviceConfig = {
                Type = lib.mkForce "exec";
                TimeoutStartSec = "30s";
                Restart = "on-failure";
                RestartSec = "10s";
              };
            };

            networking.firewall = {
              checkReversePath = "loose";
              trustedInterfaces = [ "tailscale0" ];
              allowedUDPPorts = [ 41641 ];
            };

            # NAT for exit nodes
            networking.nat = lib.mkIf exitNode {
              enable = true;
              externalInterface = lib.mkDefault (if config.networking.interfaces ? "eth0" then "eth0" else "");
              internalInterfaces = [ "tailscale0" ];
            };

            # Install tailscale CLI
            environment.systemPackages = [ pkgs.tailscale ];
          };
      };
  };
}
