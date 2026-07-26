# r[impl onix.radicle_node.hosting]
# r[impl onix.radicle_node.exposure]
{ lib }:
{
  settings,
  nodePackage,
  httpdPackage,
  policyReconciler,
  privateKeyPath,
  publicKeyPath,
  configFile,
}:
let
  httpsPort = 443;
  privateStateDirectoryMode = "0700";
  privateUmask = "0077";
  policyServiceName = "radicle-policy-reconcile";
  policyInitialDelay = "2m";
  policyInterval = "5m";
  policyJitter = "30s";
  publicHttpsEnabled =
    settings.httpdEnabled && settings.httpsEnabled && settings.httpsServerName != null;
  directAcmeHttps = publicHttpsEnabled && settings.httpsTransport == "direct-acme";
  cloudflareTunnelHttps = publicHttpsEnabled && settings.httpsTransport == "cloudflare-tunnel";
  httpBackend = "http://${settings.httpListenAddress}:${toString settings.httpListenPort}";
  mkHttpsGitLocations = import ./mk-https-git-locations.nix { inherit lib; };
  httpsGitLocations = mkHttpsGitLocations {
    backend = httpBackend;
    repositoryIds = settings.httpsGitRepositories;
  };
  policyCommand = lib.escapeShellArgs (
    [
      "${policyReconciler}/bin/radicle-policy-reconciler"
      "${nodePackage}/bin/rad"
    ]
    ++ settings.seedRepositories
    ++ settings.privateSeedRepositories
  );
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
      nginx =
        if directAcmeHttps then
          {
            enableACME = true;
            forceSSL = true;
            serverName = settings.httpsServerName;
          }
        else
          null;
    };
  };

  services.nginx = {
    enable = lib.mkIf publicHttpsEnabled true;
    virtualHosts = lib.optionalAttrs publicHttpsEnabled {
      ${settings.httpsServerName} = {
        locations = httpsGitLocations.repositories // {
          "/" = lib.mkForce httpsGitLocations.default;
        };
      }
      // lib.optionalAttrs cloudflareTunnelHttps {
        enableACME = false;
        forceSSL = false;
        listen = [
          {
            addr = settings.httpsOriginListenAddress;
            port = settings.httpsOriginListenPort;
            ssl = false;
          }
        ];
      };
    };
  };

  networking.firewall = {
    allowedTCPPorts = lib.optionals directAcmeHttps [ httpsPort ];
    interfaces.${settings.nodeFirewallInterface}.allowedTCPPorts = [ settings.nodeListenPort ];
  };

  systemd.services = {
    radicle-node.serviceConfig = serviceHardening;
    radicle-httpd = lib.mkIf settings.httpdEnabled {
      serviceConfig = serviceHardening;
    };
    ${policyServiceName} = {
      description = "Reconcile the exact Onix-managed Radicle seeding policy";
      after = [ "radicle-node.service" ];
      requires = [ "radicle-node.service" ];
      before = lib.optionals settings.httpdEnabled [ "radicle-httpd.service" ];
      requiredBy = lib.optionals settings.httpdEnabled [ "radicle-httpd.service" ];
      wantedBy = [ "multi-user.target" ];
      environment.RAD_HOME = "/var/lib/radicle";
      serviceConfig = serviceHardening // {
        BindReadOnlyPaths = [
          "${configFile}:/var/lib/radicle/config.json"
          "${publicKeyPath}:/var/lib/radicle/keys/radicle.pub"
        ];
        ExecStart = policyCommand;
        Group = "radicle";
        InaccessiblePaths = [ "/run/secrets" ];
        PrivateNetwork = true;
        RestrictAddressFamilies = [ "AF_UNIX" ];
        SocketBindDeny = "any";
        StateDirectory = [ "radicle" ];
        Type = "oneshot";
        User = "radicle";
        WorkingDirectory = "/var/lib/radicle";
      };
    };
  };

  systemd.timers.${policyServiceName} = {
    description = "Periodically enforce the Onix-managed Radicle seeding policy";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = policyInitialDelay;
      OnUnitActiveSec = policyInterval;
      Persistent = true;
      RandomizedDelaySec = policyJitter;
      Unit = "${policyServiceName}.service";
    };
  };

  environment.systemPackages = [
    nodePackage
    httpdPackage
  ];
}
