# r[impl onix.radicle_node.hosting]
# r[impl onix.radicle_node.exposure]
{ lib }:
{
  settings,
  nodePackage,
  httpdPackage,
  privateKeyPath,
  publicKeyPath,
}:
let
  httpsPort = 443;
  privateStateDirectoryMode = "0700";
  privateUmask = "0077";
  httpsEnabled = settings.httpdEnabled && settings.httpsServerName != null;
  nodeSettings = {
    inherit (settings) alias;
    relay = "always";
    seedingPolicy.default = "block";
  }
  // lib.optionalAttrs (settings.externalAddress != null) {
    externalAddresses = [ settings.externalAddress ];
  };
  serviceHardening = {
    CapabilityBoundingSet = "";
    LockPersonality = true;
    NoNewPrivileges = true;
    PrivateDevices = true;
    PrivateTmp = true;
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectHome = true;
    ProtectHostname = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectSystem = "strict";
    RemoveIPC = true;
    RestrictAddressFamilies = [
      "AF_INET"
      "AF_INET6"
      "AF_UNIX"
    ];
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    StateDirectoryMode = lib.mkForce privateStateDirectoryMode;
    SystemCallArchitectures = "native";
    UMask = lib.mkForce privateUmask;
  };
in
{
  services.radicle = {
    enable = true;
    package = nodePackage;
    privateKey = privateKeyPath;
    publicKey = publicKeyPath;
    checkConfig = true;

    node = {
      listenAddress = settings.nodeListenAddress;
      listenPort = settings.nodeListenPort;
      openFirewall = false;
    };

    settings = {
      preferredSeeds = [ ];
      node = nodeSettings;
      web.pinned.repositories = settings.pinnedRepositories;
    };

    httpd = {
      enable = settings.httpdEnabled;
      package = httpdPackage;
      listenAddress = settings.httpListenAddress;
      listenPort = settings.httpListenPort;
      nginx = if httpsEnabled then { serverName = settings.httpsServerName; } else null;
    };
  };

  services.nginx.enable = lib.mkIf httpsEnabled true;

  networking.firewall = {
    allowedTCPPorts = lib.optionals httpsEnabled [ httpsPort ];
    interfaces.${settings.nodeFirewallInterface}.allowedTCPPorts = [ settings.nodeListenPort ];
  };

  systemd.services = {
    radicle-node.serviceConfig = serviceHardening;
    radicle-httpd = lib.mkIf settings.httpdEnabled {
      serviceConfig = serviceHardening;
    };
  };

  environment.systemPackages = [
    nodePackage
    httpdPackage
  ];
}
