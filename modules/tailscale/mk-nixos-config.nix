{
  config,
  lib,
  pkgs,
  settings,
  authKeyFile,
}:
let
  inherit (settings)
    enableHostAliases
    enableSSH
    exitNode
    extraUpFlags
    ;

  tailscaleSettings = builtins.removeAttrs settings [
    "enableHostAliases"
    "enableSSH"
    "exitNode"
    "extraUpFlags"
  ];

  extraUpFlagsFinal =
    (lib.optional enableSSH "--ssh") ++ (lib.optional exitNode "--advertise-exit-node") ++ extraUpFlags;

  finalSettings = tailscaleSettings // {
    authKeyFile = lib.mkDefault authKeyFile;
    extraUpFlags = extraUpFlagsFinal;
  };

  tailscaleUdpPort = 41641;
  autoconnectStartTimeout = "30s";
  autoconnectRestartDelay = "10s";
in
{
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
      TimeoutStartSec = autoconnectStartTimeout;
      Restart = "on-failure";
      RestartSec = autoconnectRestartDelay;
    };
  };

  networking.firewall = {
    checkReversePath = "loose";
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [ tailscaleUdpPort ];
  };

  networking.nat = lib.mkIf exitNode {
    enable = true;
    externalInterface = lib.mkDefault (if config.networking.interfaces ? "eth0" then "eth0" else "");
    internalInterfaces = [ "tailscale0" ];
  };

  environment.systemPackages = [ pkgs.tailscale ];
}
