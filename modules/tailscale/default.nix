{ schema }:
{ lib, ... }:
let
  mkSettings = import ../../lib/mk-settings.nix { inherit lib; };
in
{
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
    interface = mkSettings.mkInterface schema.peer;

    perInstance =
      { instanceName, extendSettings, ... }:
      {
        nixosModule =
          {
            config,
            pkgs,
            lib,
            ...
          }:
          let
            ms = import ../../lib/mk-settings.nix { inherit lib; };
            cfg = extendSettings (ms.mkDefaults schema.peer);
            generatorName = "tailscale-${instanceName}";

            inherit (cfg)
              enableHostAliases
              enableSSH
              exitNode
              extraUpFlags
              ;

            tailscaleSettings = builtins.removeAttrs cfg [
              "enableHostAliases"
              "enableSSH"
              "exitNode"
              "extraUpFlags"
            ];

            extraUpFlagsFinal =
              (lib.optional enableSSH "--ssh") ++ (lib.optional exitNode "--advertise-exit-node") ++ extraUpFlags;

            finalSettings = tailscaleSettings // {
              # Config-dependent default — generated secret path
              authKeyFile = lib.mkDefault config.clan.core.vars.generators."${generatorName}".files.auth_key.path;
              extraUpFlags = extraUpFlagsFinal;
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

            networking.nat = lib.mkIf exitNode {
              enable = true;
              externalInterface = lib.mkDefault (if config.networking.interfaces ? "eth0" then "eth0" else "");
              internalInterfaces = [ "tailscale0" ];
            };

            environment.systemPackages = [ pkgs.tailscale ];
          };
      };
  };
}
