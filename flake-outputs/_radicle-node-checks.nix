# r[verify onix.radicle_node.package]
# r[verify onix.radicle_node.configuration]
# r[verify onix.radicle_node.hosting]
# r[verify onix.radicle_node.exposure]
# r[verify onix.radicle_node.validation]
{
  self,
  pkgs,
  lib,
  system,
  ...
}:
let
  privateStateDirectoryMode = "0700";
  reviewedNodeVersion = "1.9.1";
  reviewedHttpdVersion = "0.25.0";
  minimumRejectedNodeVersion = "1.9.0";
  expectedHost = "aspen1";
  unexpectedHost = "aspen2";
  deploymentTarget = "root@aspen1.local";
  expectedNodeFingerprint = "SHA256:zwNJTV2uBfWYcFXeFJs+eAfatqahgK8KKe+4gdGkOSE";
  nodeAddress = "100.100.103.95";
  nodePort = 8776;
  nodeInterface = "tailscale0";
  httpAddress = "127.0.0.1";
  httpPort = 8080;
  httpsPort = 443;
  httpsServerName = "git.onix.example";
  httpsTransport = "cloudflare-tunnel";
  httpsOriginAddress = "127.0.0.1";
  httpsOriginPort = 8081;
  httpsBackend = "http://${httpAddress}:${toString httpPort}";
  backupTargetHost = "britton-desktop";
  backupTargetAddress = "100.110.43.11";
  backupTargetFailureDomain = "britton-desktop-workstation";
  backupRepositoryPath = "/var/lib/radicle-backup";
  backupRepository = "${backupRepositoryPath}/${expectedHost}";
  backupDataset = "datapool/radicle-backup";
  backupDatasetQuotaGiB = 256;
  undersizedBackupQuotaGiB = 64;
  backupRetentionDaily = 7;
  backupRetentionWeekly = 4;
  unboundedDailyRetention = 365;
  backupManifestAlgorithm = "blake3";
  radiclePrivateBackupCredential = "radicle-node-private";
  borgSshBackupCredential = "borg-ssh";
  borgRepoKeyBackupCredential = "borg-repokey";
  backupUnitName = "borgbackup-job-${backupTargetHost}";
  backupCredentialDirectory = "/run/credentials/${backupUnitName}.service";
  backupBorgRuntimeRoot = "/run/radicle-backup-borg";
  identityGeneratorName = "radicle-node-radicle-forge-bootstrap";
  privateKeyFileName = "node-private-key";
  publicKeyFileName = "node-public-key";
  policyServiceName = "radicle-policy-reconcile";
  policyInitialDelay = "2m";
  policyInterval = "5m";
  policyJitter = "30s";
  generatedPrivateKeyMode = "400";
  generatedPublicKeyMode = "444";
  optionalPassphraseCredential = "dev.radicle.node.passphrase";
  pinnedRepository = "rad:z3gqcJUoA1n9HaHKufZs5FCSGazv5";
  productionPilotRepository = "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo";
  productionHttpsServerName = "git.onix.computer";
  productionCloudflareTunnelName = "aspen1-services";

  nodePackage = self.packages.${system}.radicle-node;
  httpdPackage = self.packages.${system}.radicle-httpd;
  policyReconciler = import ../modules/radicle-node/policy-reconciler.nix { inherit pkgs; };
  backupManifest = import ../modules/radicle-node/backup-manifest.nix { inherit pkgs; };
  validateSettings = import ../modules/radicle-node/validate-settings.nix { inherit lib; };
  mkHttpsGitLocations = import ../modules/radicle-node/mk-https-git-locations.nix { inherit lib; };
  mkNixosConfig = import ../modules/radicle-node/mk-nixos-config.nix { inherit lib; };

  positiveSettings = {
    inherit deploymentTarget;
    inherit expectedHost;
    inherit expectedNodeFingerprint;
    alias = "aspen1-radicle";
    failureDomain = "aspen-primary-site";
    monitoringRequired = true;
    nodeListenAddress = nodeAddress;
    nodeListenPort = nodePort;
    nodeFirewallInterface = nodeInterface;
    externalAddress = "${nodeAddress}:${toString nodePort}";
    seedRepositories = [ pinnedRepository ];
    httpdEnabled = true;
    httpListenAddress = httpAddress;
    httpListenPort = httpPort;
    httpsEnabled = false;
    httpsServerName = "git.onix.computer";
    inherit httpsTransport;
    httpsOriginListenAddress = httpsOriginAddress;
    httpsOriginListenPort = httpsOriginPort;
    httpsGitRepositories = [ ];
    backupEnabled = true;
    inherit
      backupTargetHost
      backupTargetAddress
      backupTargetFailureDomain
      backupRepositoryPath
      backupDataset
      backupDatasetQuotaGiB
      backupRetentionDaily
      backupRetentionWeekly
      backupManifestAlgorithm
      ;
    minimumSignedRefsFeature = "parent";
    pinnedRepositories = [ pinnedRepository ];
  };

  positiveValidationErrors = validateSettings {
    settings = positiveSettings;
    packageVersion = nodePackage.version;
    actualHost = expectedHost;
  };

  httpsSettings = positiveSettings // {
    httpsEnabled = true;
    inherit httpsServerName;
    httpsGitRepositories = [ pinnedRepository ];
  };
  httpsModuleConfig = mkNixosConfig {
    settings = httpsSettings;
    inherit nodePackage httpdPackage policyReconciler;
    privateKeyPath = "/run/credentials/radicle-node.service/dev.radicle.node.secret";
    publicKeyPath = "/var/lib/radicle/keys/radicle.pub";
    configFile = "/var/lib/radicle/config.json";
  };
  directAcmeHttpsModuleConfig = mkNixosConfig {
    settings = httpsSettings // {
      httpsTransport = "direct-acme";
    };
    inherit nodePackage httpdPackage policyReconciler;
    privateKeyPath = "/run/credentials/radicle-node.service/dev.radicle.node.secret";
    publicKeyPath = "/var/lib/radicle/keys/radicle.pub";
    configFile = "/var/lib/radicle/config.json";
  };
  mkHttpsTestSystem =
    moduleConfig:
    lib.nixosSystem {
      inherit system;
      modules = [
        moduleConfig
        {
          networking.hostName = expectedHost;
          system.stateVersion = "26.11";
        }
      ];
    };
  cloudflareHttpsTestConfig = (mkHttpsTestSystem httpsModuleConfig).config;
  directAcmeHttpsTestConfig = (mkHttpsTestSystem directAcmeHttpsModuleConfig).config;
  cloudflareHttpsVhost = cloudflareHttpsTestConfig.services.nginx.virtualHosts.${httpsServerName};
  directAcmeHttpsVhost = directAcmeHttpsTestConfig.services.nginx.virtualHosts.${httpsServerName};
  cloudflareNginxCommand = cloudflareHttpsTestConfig.systemd.services.nginx.serviceConfig.ExecStart;
  directAcmeNginxCommand = directAcmeHttpsTestConfig.systemd.services.nginx.serviceConfig.ExecStart;
  directAcmeHttpsPolicyValid =
    directAcmeHttpsTestConfig.services.radicle.httpd.nginx.serverName == httpsServerName
    && directAcmeHttpsVhost.enableACME
    && directAcmeHttpsVhost.forceSSL
    && builtins.elem httpsPort directAcmeHttpsTestConfig.networking.firewall.allowedTCPPorts;
  httpsGitLocations = mkHttpsGitLocations {
    backend = httpsBackend;
    repositoryIds = httpsSettings.httpsGitRepositories;
  };
  httpsRepositoryPath = lib.removePrefix "rad:" pinnedRepository;
  infoRefsLocationName = "= /${httpsRepositoryPath}.git/info/refs";
  uploadPackLocationName = "= /${httpsRepositoryPath}.git/git-upload-pack";
  expectedHttpsLocationNames = [
    infoRefsLocationName
    uploadPackLocationName
  ];
  actualHttpsLocationNames = builtins.attrNames httpsGitLocations.repositories;
  infoRefsLocation = httpsGitLocations.repositories.${infoRefsLocationName};
  uploadPackLocation = httpsGitLocations.repositories.${uploadPackLocationName};
  rawLoweredHttpsLocations =
    httpsModuleConfig.services.nginx.virtualHosts.${httpsServerName}.locations;
  rawLoweredDefaultLocation = rawLoweredHttpsLocations."/";
  loweredHttpsLocations = cloudflareHttpsVhost.locations;
  loweredDefaultLocation = loweredHttpsLocations."/";
  httpsRoutePolicyValid =
    actualHttpsLocationNames == lib.sort builtins.lessThan expectedHttpsLocationNames
    && httpsGitLocations.default.return == 404
    && infoRefsLocation.proxyPass == httpsBackend
    && uploadPackLocation.proxyPass == httpsBackend
    && lib.hasInfix ''if ($args != "service=git-upload-pack")'' infoRefsLocation.extraConfig
    && lib.hasInfix "limit_except GET" infoRefsLocation.extraConfig
    && lib.hasInfix ''if ($args != "")'' uploadPackLocation.extraConfig
    && lib.hasInfix "limit_except POST" uploadPackLocation.extraConfig
    && builtins.hasAttr infoRefsLocationName rawLoweredHttpsLocations
    && builtins.hasAttr uploadPackLocationName rawLoweredHttpsLocations
    && rawLoweredDefaultLocation._type == "override"
    && rawLoweredDefaultLocation.content.return == 404
    && loweredDefaultLocation.return == 404
    && cloudflareHttpsTestConfig.services.radicle.httpd.nginx == null
    && cloudflareHttpsVhost.enableACME == false
    && cloudflareHttpsVhost.forceSSL == false
    && builtins.length cloudflareHttpsVhost.listen == 1
    && (builtins.head cloudflareHttpsVhost.listen).addr == httpsOriginAddress
    && (builtins.head cloudflareHttpsVhost.listen).port == httpsOriginPort
    && (builtins.head cloudflareHttpsVhost.listen).ssl == false
    && !(builtins.elem httpsPort cloudflareHttpsTestConfig.networking.firewall.allowedTCPPorts);

  negativeCases = [
    {
      name = "old-package";
      settings = positiveSettings;
      packageVersion = minimumRejectedNodeVersion;
      actualHost = expectedHost;
      expected = "version ${reviewedNodeVersion} or later";
    }
    {
      name = "wrong-selected-host";
      settings = positiveSettings // {
        expectedHost = unexpectedHost;
      };
      packageVersion = nodePackage.version;
      actualHost = unexpectedHost;
      expected = "expectedHost must remain ${expectedHost}";
    }
    {
      name = "wrong-actual-host";
      settings = positiveSettings;
      packageVersion = nodePackage.version;
      actualHost = unexpectedHost;
      expected = "evaluated only on the selected host";
    }
    {
      name = "wrong-deployment-target";
      settings = positiveSettings // {
        deploymentTarget = "root@${nodeAddress}";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "deploymentTarget must remain ${deploymentTarget}";
    }
    {
      name = "rotated-node-identity";
      settings = positiveSettings // {
        expectedNodeFingerprint = "SHA256:unexpected";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "must preserve the recovered Aspen1 node identity";
    }
    {
      name = "missing-alias";
      settings = positiveSettings // {
        alias = "";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "alias must not be empty";
    }
    {
      name = "missing-failure-domain";
      settings = positiveSettings // {
        failureDomain = "";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "failureDomain must not be empty";
    }
    {
      name = "monitoring-disabled";
      settings = positiveSettings // {
        monitoringRequired = false;
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "monitoringRequired must remain enabled";
    }
    {
      name = "wildcard-node-listener";
      settings = positiveSettings // {
        nodeListenAddress = "0.0.0.0";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "must not be a wildcard address";
    }
    {
      name = "loopback-node-listener";
      settings = positiveSettings // {
        nodeListenAddress = httpAddress;
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "must not be loopback";
    }
    {
      name = "loopback-firewall-interface";
      settings = positiveSettings // {
        nodeFirewallInterface = "lo";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "must name one non-loopback interface";
    }
    {
      name = "url-shaped-external-address";
      settings = positiveSettings // {
        externalAddress = "https://seed.example";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "host:nodeListenPort Radicle address without a URL scheme";
    }
    {
      name = "external-port-mismatch";
      settings = positiveSettings // {
        externalAddress = "${nodeAddress}:${toString httpPort}";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "host:nodeListenPort Radicle address without a URL scheme";
    }
    {
      name = "port-collision";
      settings = positiveSettings // {
        httpListenPort = nodePort;
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "nodeListenPort and httpListenPort must be distinct";
    }
    {
      name = "wildcard-http-listener";
      settings = positiveSettings // {
        httpListenAddress = "[::]";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "httpListenAddress must remain loopback-only";
    }
    {
      name = "invalid-https-transport";
      settings = positiveSettings // {
        httpsTransport = "plaintext";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "httpsTransport must be direct-acme or cloudflare-tunnel";
    }
    {
      name = "wildcard-https-origin";
      settings = positiveSettings // {
        httpsOriginListenAddress = "0.0.0.0";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "httpsOriginListenAddress must remain loopback-only";
    }
    {
      name = "https-origin-port-collision";
      settings = positiveSettings // {
        httpsOriginListenPort = httpPort;
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "httpsOriginListenPort, HTTPS, native peer, and HTTP gateway ports must be distinct";
    }
    {
      name = "https-without-httpd";
      settings = positiveSettings // {
        httpdEnabled = false;
        httpsEnabled = true;
        httpsGitRepositories = [ pinnedRepository ];
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "httpsEnabled requires the read-only HTTP gateway";
    }
    {
      name = "https-without-server-name";
      settings = positiveSettings // {
        httpsEnabled = true;
        httpsServerName = null;
        httpsGitRepositories = [ pinnedRepository ];
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "public HTTPS activation requires a server name";
    }
    {
      name = "https-port-collision";
      settings = positiveSettings // {
        nodeListenPort = httpsPort;
        externalAddress = "${nodeAddress}:${toString httpsPort}";
        httpsEnabled = true;
        httpsServerName = "code.onix.example";
        httpsGitRepositories = [ pinnedRepository ];
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "HTTPS, native peer, and HTTP gateway ports must be distinct";
    }
    {
      name = "mdns-https-name";
      settings = positiveSettings // {
        httpsServerName = "aspen1.local";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "public DNS name";
    }
    {
      name = "invalid-seed-rid";
      settings = positiveSettings // {
        seedRepositories = [ "rad:../host-secret" ];
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "seedRepositories must contain only canonical public rad:z repository IDs";
    }
    {
      name = "duplicate-seed-rid";
      settings = positiveSettings // {
        seedRepositories = [
          pinnedRepository
          pinnedRepository
        ];
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "seedRepositories must not contain duplicate repository IDs";
    }
    {
      name = "https-without-allowlist";
      settings = positiveSettings // {
        httpsEnabled = true;
        inherit httpsServerName;
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "public HTTPS activation requires a server name and non-empty HTTPS Git repository allowlist";
    }
    {
      name = "allowlist-without-https";
      settings = positiveSettings // {
        httpsGitRepositories = [ pinnedRepository ];
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "an allowlist requires activation";
    }
    {
      name = "invalid-https-rid";
      settings = positiveSettings // {
        httpsEnabled = true;
        inherit httpsServerName;
        httpsGitRepositories = [ "rad:../host-secret" ];
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "only canonical public rad:z repository IDs";
    }
    {
      name = "duplicate-https-rid";
      settings = positiveSettings // {
        httpsEnabled = true;
        inherit httpsServerName;
        httpsGitRepositories = [
          pinnedRepository
          pinnedRepository
        ];
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "httpsGitRepositories must not contain duplicate repository IDs";
    }
    {
      name = "https-repository-not-seeded";
      settings = positiveSettings // {
        httpsEnabled = true;
        inherit httpsServerName;
        seedRepositories = [ ];
        httpsGitRepositories = [ pinnedRepository ];
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "httpsGitRepositories must be a subset of seedRepositories";
    }
    {
      name = "backup-disabled-with-target-facts";
      settings = positiveSettings // {
        backupEnabled = false;
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "backup activation and complete reviewed target facts must agree";
    }
    {
      name = "backup-missing-target";
      settings = positiveSettings // {
        backupTargetHost = null;
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "enabled backup requires complete target host";
    }
    {
      name = "backup-target-not-reviewed";
      settings = positiveSettings // {
        backupTargetHost = "aspen2";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "backup target must remain the reviewed britton-desktop dataset and address";
    }
    {
      name = "backup-same-failure-domain";
      settings = positiveSettings // {
        backupTargetFailureDomain = "aspen-primary-site";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "backup target host and failure domain must differ";
    }
    {
      name = "backup-quota-too-small";
      settings = positiveSettings // {
        backupDatasetQuotaGiB = undersizedBackupQuotaGiB;
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "backupDatasetQuotaGiB must remain between 128 and 1024 GiB";
    }
    {
      name = "backup-retention-unbounded";
      settings = positiveSettings // {
        backupRetentionDaily = unboundedDailyRetention;
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "backup retention must remain positive and bounded";
    }
    {
      name = "backup-wrong-manifest-algorithm";
      settings = positiveSettings // {
        backupManifestAlgorithm = "sha256";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "backupManifestAlgorithm must remain blake3";
    }
    {
      name = "pinned-repository-not-seeded";
      settings = positiveSettings // {
        seedRepositories = [ ];
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "pinnedRepositories must be a subset of seedRepositories";
    }
    {
      name = "weak-signed-refs";
      settings = positiveSettings // {
        minimumSignedRefsFeature = "root";
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "minimumSignedRefsFeature must remain parent";
    }
    {
      name = "invalid-rid";
      settings = positiveSettings // {
        pinnedRepositories = [ "github:OnixResearch/bounded-exec" ];
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "only canonical rad:z repository IDs";
    }
    {
      name = "duplicate-rid";
      settings = positiveSettings // {
        pinnedRepositories = [
          pinnedRepository
          pinnedRepository
        ];
      };
      packageVersion = nodePackage.version;
      actualHost = expectedHost;
      expected = "must not contain duplicate repository IDs";
    }
  ];

  negativeFailures = builtins.filter (
    case:
    let
      errors = validateSettings {
        inherit (case) settings packageVersion actualHost;
      };
    in
    !(lib.any (error: lib.hasInfix case.expected error) errors)
  ) negativeCases;

  fixtureConfig = self.nixosConfigurations.${expectedHost}.config;
  aspen2Config = self.nixosConfigurations.aspen2.config;
  aspen3Config = self.nixosConfigurations.aspen3.config;
  desktopConfig = self.nixosConfigurations.${backupTargetHost}.config;
  backupJob = fixtureConfig.services.borgbackup.jobs.${backupTargetHost} or null;
  backupService = fixtureConfig.systemd.services."borgbackup-job-${backupTargetHost}";
  backupGeneratorFiles = fixtureConfig.clan.core.vars.generators.borgbackup.files;
  expectedBackupCredentials = [
    "${radiclePrivateBackupCredential}:${privateKeyPath}"
    "${borgSshBackupCredential}:${backupGeneratorFiles."borgbackup.ssh".path}"
    "${borgRepoKeyBackupCredential}:${backupGeneratorFiles."borgbackup.repokey".path}"
  ];
  backupLoadedCredentials = lib.toList (backupService.serviceConfig.LoadCredential or [ ]);
  backupBindPaths = lib.toList (backupService.serviceConfig.BindReadOnlyPaths or [ ]);
  backupTargetRepo = desktopConfig.services.borgbackup.repos.${expectedHost} or null;
  backupTargetRepoService = desktopConfig.systemd.services.borgbackup-repo-aspen1;
  backupTargetFileSystem = desktopConfig.fileSystems.${backupRepositoryPath} or null;
  backupAuthorizedKeys = desktopConfig.users.users.borg.openssh.authorizedKeys.keys or [ ];
  backupStateBind = "/var/lib/radicle:/run/radicle-backup-source";
  expectedBackupPaths = [
    "/run/radicle-backup-source"
    "/run/radicle-backup-input"
    "/run/radicle-backup-manifests"
  ];
  backupSourcePolicyValid =
    backupJob != null
    && backupJob.paths == expectedBackupPaths
    && backupJob.exclude == [ ]
    && backupJob.repo == "borg@${backupTargetAddress}:."
    && backupJob.compression == "auto,lz4"
    && backupJob.encryption.mode == "repokey"
    && backupJob.environment.BORG_BASE_DIR == backupBorgRuntimeRoot
    && backupJob.environment.BORG_CACHE_DIR == "${backupBorgRuntimeRoot}/cache"
    && backupJob.environment.BORG_CONFIG_DIR == "${backupBorgRuntimeRoot}/config"
    && backupJob.environment.BORG_SECURITY_DIR == "${backupBorgRuntimeRoot}/security"
    && backupJob.prune.keep.daily == backupRetentionDaily
    && backupJob.prune.keep.weekly == backupRetentionWeekly
    && lib.hasInfix "${backupCredentialDirectory}/${borgSshBackupCredential}" backupJob.environment.BORG_RSH
    && lib.hasInfix "${backupCredentialDirectory}/${borgRepoKeyBackupCredential}" backupJob.encryption.passCommand
    && lib.hasInfix "StrictHostKeyChecking=yes" backupJob.environment.BORG_RSH
    && lib.hasInfix "HostKeyAlgorithms=ssh-ed25519" backupJob.environment.BORG_RSH
    && !(lib.hasInfix "accept-new" backupJob.environment.BORG_RSH)
    && lib.hasInfix "radicle-backup-prepare" backupJob.preHook
    && lib.hasInfix "radicle-backup-cleanup" backupJob.postHook
    && lib.subtractLists expectedBackupCredentials backupLoadedCredentials == [ ]
    && lib.subtractLists backupLoadedCredentials expectedBackupCredentials == [ ]
    && backupBindPaths == [ backupStateBind ]
    && builtins.elem "/run/secrets" backupService.serviceConfig.InaccessiblePaths
    && builtins.elem "/var/lib" backupService.serviceConfig.InaccessiblePaths
    && backupService.serviceConfig.AmbientCapabilities == [ "CAP_DAC_READ_SEARCH" ]
    && backupService.serviceConfig.CapabilityBoundingSet == [ "CAP_DAC_READ_SEARCH" ]
    && backupService.serviceConfig.NoNewPrivileges
    && backupService.serviceConfig.PrivateDevices
    && backupService.serviceConfig.ProtectHome
    && backupService.serviceConfig.ProtectSystem == "strict"
    && backupService.serviceConfig.RuntimeDirectory == "radicle-backup-borg"
    && backupService.serviceConfig.RuntimeDirectoryMode == "0700"
    && builtins.length backupService.serviceConfig.ExecStartPre == 1
    && lib.hasInfix "radicle-backup-repository-preflight" (
      builtins.head backupService.serviceConfig.ExecStartPre
    );
  backupTargetPolicyValid =
    backupTargetRepo != null
    && backupTargetRepo.path == backupRepository
    && backupTargetRepo.quota == "${toString backupDatasetQuotaGiB}G"
    && !backupTargetRepo.allowSubRepos
    && backupTargetFileSystem != null
    && backupTargetFileSystem.device == backupDataset
    && builtins.length backupAuthorizedKeys == 1
    && lib.hasInfix "--restrict-to-repository" (builtins.head backupAuthorizedKeys)
    && lib.hasInfix "quota=${toString backupDatasetQuotaGiB}G" desktopConfig.system.activationScripts.radicle-backup-zfs-dataset.text
    && lib.hasInfix "chown root:borg" desktopConfig.system.activationScripts.radicle-backup-zfs-dataset.text
    && lib.hasInfix "chmod 0710" desktopConfig.system.activationScripts.radicle-backup-zfs-dataset.text
    && lib.hasInfix "-m 0700" backupTargetRepoService.script
    && lib.hasInfix "-o borg" backupTargetRepoService.script
    && backupTargetRepoService.serviceConfig.UMask == "0077"
    && builtins.elem backupRepositoryPath backupTargetRepoService.unitConfig.RequiresMountsFor;
  radicleServiceAbsent = config: !(builtins.hasAttr "radicle-node" config.systemd.services);
  identityGeneratorAbsent =
    config: !(builtins.hasAttr identityGeneratorName config.clan.core.vars.generators);

  failedAssertions = builtins.filter (assertion: !assertion.assertion) fixtureConfig.assertions;
  nodeService = fixtureConfig.systemd.services.radicle-node;
  httpdService = fixtureConfig.systemd.services.radicle-httpd;
  policyService = fixtureConfig.systemd.services.${policyServiceName};
  policyTimer = fixtureConfig.systemd.timers.${policyServiceName};
  nodeCommand = nodeService.serviceConfig.ExecStart;
  httpdCommand = httpdService.serviceConfig.ExecStart;
  policyCommand = builtins.unsafeDiscardStringContext policyService.serviceConfig.ExecStart;
  productionHttpsVhost = fixtureConfig.services.nginx.virtualHosts.${productionHttpsServerName};
  productionHttpsLocations = productionHttpsVhost.locations;
  productionHttpsRepositoryPath = lib.removePrefix "rad:" productionPilotRepository;
  productionInfoRefsLocationName = "= /${productionHttpsRepositoryPath}.git/info/refs";
  productionUploadPackLocationName = "= /${productionHttpsRepositoryPath}.git/git-upload-pack";
  productionExpectedLocationNames = lib.sort builtins.lessThan [
    "/"
    productionInfoRefsLocationName
    productionUploadPackLocationName
  ];
  productionCloudflareTunnel =
    fixtureConfig.services.cloudflared.tunnels.${productionCloudflareTunnelName};
  policyReconcilerCommandPath = builtins.unsafeDiscardStringContext "${policyReconciler}/bin/radicle-policy-reconciler";
  nodeRadCommandPath = builtins.unsafeDiscardStringContext "${nodePackage}/bin/rad";
  identityGenerator = fixtureConfig.clan.core.vars.generators.${identityGeneratorName};
  privateKeyFile = identityGenerator.files.${privateKeyFileName};
  publicKeyFile = identityGenerator.files.${publicKeyFileName};
  privateKeyPath = privateKeyFile.path;
  publicKeyPath = publicKeyFile.path;
  loadedPrivateKeyCredential = "dev.radicle.node.secret:${privateKeyPath}";
  expectedPublicKeyBind = "${publicKeyPath}:/var/lib/radicle/keys/radicle.pub";
  nodeImportedCredentials = lib.toList (nodeService.serviceConfig.ImportCredential or [ ]);
  nodeLoadedCredentials = lib.toList (nodeService.serviceConfig.LoadCredential or [ ]);
  httpdImportedCredentials = lib.toList (httpdService.serviceConfig.ImportCredential or [ ]);
  httpdLoadedCredentials = lib.toList (httpdService.serviceConfig.LoadCredential or [ ]);
  policyImportedCredentials = lib.toList (policyService.serviceConfig.ImportCredential or [ ]);
  policyLoadedCredentials = lib.toList (policyService.serviceConfig.LoadCredential or [ ]);
  unexpectedNodeImports = lib.subtractLists [ optionalPassphraseCredential ] nodeImportedCredentials;
  unexpectedNodeLoads = lib.subtractLists [ loadedPrivateKeyCredential ] nodeLoadedCredentials;
  nodeBindPaths = lib.toList (nodeService.serviceConfig.BindReadOnlyPaths or [ ]);
  httpdBindPaths = lib.toList (httpdService.serviceConfig.BindReadOnlyPaths or [ ]);
  policyBindPaths = lib.toList (policyService.serviceConfig.BindReadOnlyPaths or [ ]);
  expectedPolicyConfigBind = "${fixtureConfig.services.radicle.configFile}:/var/lib/radicle/config.json";
  expectedPolicyPublicKeyBind = "${publicKeyPath}:/var/lib/radicle/keys/radicle.pub";
  unexpectedSecretBindPaths = builtins.filter (
    path: lib.hasInfix "/run/secrets" path && path != expectedPublicKeyBind
  ) (nodeBindPaths ++ httpdBindPaths ++ policyBindPaths);
  globalFirewallPorts = fixtureConfig.networking.firewall.allowedTCPPorts;
  interfaceFirewallPorts =
    fixtureConfig.networking.firewall.interfaces.${nodeInterface}.allowedTCPPorts;
  monitoringRules = lib.concatStringsSep "\n" fixtureConfig.services.prometheus.rules;
  monitoringPolicyValid =
    fixtureConfig.services.prometheus.enable
    && fixtureConfig.services.prometheus.exporters.systemd.enable
    && lib.hasInfix "alert: RadicleNodeNotActive" monitoringRules
    && lib.hasInfix ''systemd_unit_state{name="radicle-node.service",state="active"} != 1'' monitoringRules
    && lib.hasInfix "alert: RadicleHttpdNotActive" monitoringRules
    && lib.hasInfix ''systemd_unit_state{name="radicle-httpd.service",state="active"} != 1'' monitoringRules
    && lib.hasInfix "alert: RadiclePolicyReconcileFailed" monitoringRules
    && lib.hasInfix ''systemd_unit_state{name="radicle-policy-reconcile.service",state="failed"} == 1'' monitoringRules;

  plugins = self.packages.x86_64-linux.wasm-plugins;
  wasm = import ../lib/wasm.nix { inherit plugins; };
  schemaValidation = wasm.evalNickelFile ../inventory/services/fixtures/radicle-node-validation.ncl;
  bootstrapReceiptSource = ../evidence/radicle/bootstrap-v1.ncl;
  bootstrapReceiptJsonPath = ../evidence/radicle/bootstrap-v1.json;
  bootstrapReceiptHashPath = ../evidence/radicle/bootstrap-v1.blake3;
  bootstrapReceipt = wasm.evalNickelFile bootstrapReceiptSource;
  bootstrapReceiptJson = builtins.fromJSON (builtins.readFile bootstrapReceiptJsonPath);
  bootstrapReceiptExpectedHash = lib.removeSuffix "\n" (builtins.readFile bootstrapReceiptHashPath);
  bootstrapReceiptSchemaVersion = 1;
  bootstrapReceiptType = "onix.radicle.bootstrap.v1";
  bootstrapReceiptStatus = "accepted";
  notFoundStatus = 404;
  expectedBootstrapReceiptFields = lib.sort lib.lessThan [
    "acquisition"
    "authority_boundary"
    "endpoints"
    "evidence"
    "identity"
    "machine"
    "monitoring"
    "non_claims"
    "observed_date"
    "packages"
    "policy"
    "receipt_type"
    "recovery"
    "rejection_probes"
    "repositories"
    "schema_version"
    "services"
    "status"
  ];
  bootstrapReceiptIsAccepted =
    receipt:
    builtins.attrNames receipt == expectedBootstrapReceiptFields
    && receipt.schema_version == bootstrapReceiptSchemaVersion
    && receipt.receipt_type == bootstrapReceiptType
    && receipt.status == bootstrapReceiptStatus
    && receipt.policy.minimum_node_version == reviewedNodeVersion
    && receipt.policy.minimum_signed_refs_feature == "parent"
    && receipt.packages.node.version == reviewedNodeVersion
    && receipt.packages.httpd.version == reviewedHttpdVersion
    && receipt.machine.host == expectedHost
    && receipt.machine.deployment_target == deploymentTarget
    && receipt.identity.node_id == "z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8"
    && receipt.identity.ssh_fingerprint == expectedNodeFingerprint
    &&
      receipt.repositories == [
        {
          rid = productionPilotRepository;
          visibility = "public";
          expected_commit = "29dac88ecded94457572db3fdfaaaab95fa91525";
          observed_commit = "29dac88ecded94457572db3fdfaaaab95fa91525";
          source_archive_blake3 = "4fbbf8f0749262469f00748e04c775180488dba800303f139172656d25931927";
        }
      ]
    && receipt.acquisition.native.result == "verified"
    && receipt.acquisition.native.signed_refs_feature == "parent"
    && receipt.acquisition.https_git.result == "verified"
    && receipt.endpoints.https_git.upload_pack_only
    && receipt.rejection_probes.native_undeclared_rid == "rejected"
    && receipt.rejection_probes.https_undeclared_rid_status == notFoundStatus
    && receipt.rejection_probes.https_receive_pack_status == notFoundStatus
    && receipt.rejection_probes.https_write == "rejected"
    && receipt.services.reconciled_repository_count == 1
    && receipt.authority_boundary.allowed_credentials == [ "machine-scoped-radicle-node-key" ]
    && receipt.authority_boundary.host_secrets_masked
    && receipt.authority_boundary.home_protected
    && receipt.authority_boundary.capability_bounding_set_empty
    && receipt.recovery.result == "verified"
    && receipt.recovery.restored_node_id == receipt.identity.node_id
    && receipt.recovery.restored_fingerprint == receipt.identity.ssh_fingerprint
    && builtins.elem "independent-seed-availability" receipt.non_claims
    && builtins.elem "single-seed-outage-survival" receipt.non_claims
    && builtins.elem "private-repository-confidentiality" receipt.non_claims;
  invalidBootstrapReceipts = [
    (bootstrapReceipt // { status = "rejected"; })
    (
      bootstrapReceipt
      // {
        repositories = map (
          repository: repository // { observed_commit = "0000000000000000000000000000000000000000"; }
        ) bootstrapReceipt.repositories;
      }
    )
    (bootstrapReceipt // { non_claims = [ ]; })
    (bootstrapReceipt // { private_key = "must-not-be-accepted"; })
  ];
  invalidBootstrapReceiptsAccepted = builtins.filter bootstrapReceiptIsAccepted invalidBootstrapReceipts;
  bootstrapReceiptPolicyValid =
    bootstrapReceipt == bootstrapReceiptJson
    && bootstrapReceiptIsAccepted bootstrapReceipt
    && invalidBootstrapReceiptsAccepted == [ ];
  schemaExpectedNegativeFields = [
    "expectedHost"
    "deploymentTarget"
    "expectedNodeFingerprint"
    "alias"
    "failureDomain"
    "monitoringRequired"
    "nodeListenAddress"
    "nodeListenPort"
    "nodeFirewallInterface"
    "externalAddress"
    "seedRepositories"
    "httpdEnabled"
    "httpListenAddress"
    "httpListenPort"
    "httpsEnabled"
    "httpsServerName"
    "httpsTransport"
    "httpsOriginListenAddress"
    "httpsOriginListenPort"
    "httpsGitRepositories"
    "backupEnabled"
    "backupTargetHost"
    "backupTargetAddress"
    "backupTargetFailureDomain"
    "backupRepositoryPath"
    "backupDataset"
    "backupDatasetQuotaGiB"
    "backupRetentionDaily"
    "backupRetentionWeekly"
    "backupManifestAlgorithm"
    "minimumSignedRefsFeature"
    "pinnedRepositories"
  ];
  missingSchemaNegativeFields = builtins.filter (
    field: !(lib.any (error: lib.hasInfix field error) schemaValidation.negative)
  ) schemaExpectedNegativeFields;
in
{
  checks = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    radicle-node-policy =
      pkgs.runCommand "radicle-node-policy"
        {
          nativeBuildInputs = [
            pkgs.b3sum
            pkgs.coreutils
            pkgs.nickel
            pkgs.openssh
          ];
        }
        ''
          test -x ${nodePackage}/bin/rad
          test -x ${nodePackage}/bin/radicle-node
          test -x ${httpdPackage}/bin/radicle-httpd
          test -x ${policyReconciler}/bin/radicle-policy-reconciler
          test -x ${backupManifest}/bin/radicle-backup-manifest
          test -e ${fixtureConfig.services.radicle.configFile}
          test -n ${lib.escapeShellArg cloudflareNginxCommand}
          test -n ${lib.escapeShellArg directAcmeNginxCommand}

          nickel export --format json ${bootstrapReceiptSource} > "$TMPDIR/bootstrap-v1.json"
          test -s "$TMPDIR/bootstrap-v1.json"
          test "$(b3sum ${bootstrapReceiptJsonPath} | cut -d ' ' -f 1)" = ${lib.escapeShellArg bootstrapReceiptExpectedHash}

          ${lib.optionalString (!bootstrapReceiptPolicyValid) ''
            echo "typed Radicle bootstrap receipt or its negative fixtures failed semantic validation" >&2
            exit 1
          ''}

          configured_fingerprint="$(ssh-keygen -lf ${publicKeyPath})"
          case "$configured_fingerprint" in
            *" ${expectedNodeFingerprint} "*) ;;
            *)
              echo "configured Radicle public key does not preserve the recovered Aspen1 identity" >&2
              exit 1
              ;;
          esac

          ${lib.optionalString (nodePackage.version != reviewedNodeVersion) ''
            echo "radicle-node version changed without updating the reviewed package identity" >&2
            exit 1
          ''}
          ${lib.optionalString (httpdPackage.version != reviewedHttpdVersion) ''
            echo "radicle-httpd version changed without updating the reviewed package identity" >&2
            exit 1
          ''}
          ${lib.optionalString (positiveValidationErrors != [ ]) ''
            echo "valid Radicle settings were rejected:" >&2
            printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" positiveValidationErrors)} >&2
            exit 1
          ''}
          ${lib.optionalString (negativeFailures != [ ]) ''
            echo "Radicle negative fixtures missed expected diagnostics:" >&2
            printf '%s\n' ${
              lib.escapeShellArg (lib.concatStringsSep "\n" (map (case: case.name) negativeFailures))
            } >&2
            exit 1
          ''}
          ${lib.optionalString (schemaValidation.positive != [ ]) ''
            echo "valid Nickel Radicle settings produced type errors" >&2
            printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" schemaValidation.positive)} >&2
            exit 1
          ''}
          ${lib.optionalString (missingSchemaNegativeFields != [ ]) ''
            echo "invalid Nickel Radicle settings missed expected fields" >&2
            printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" missingSchemaNegativeFields)} >&2
            exit 1
          ''}
          ${lib.optionalString (!httpsRoutePolicyValid) ''
            echo "Cloudflare HTTPS Git proxy routes do not fail closed around the admitted repository set" >&2
            printf '%s\n' ${
              lib.escapeShellArg (
                builtins.toJSON {
                  inherit actualHttpsLocationNames expectedHttpsLocationNames;
                  defaultReturn = loweredDefaultLocation.return or null;
                  httpdNginx = cloudflareHttpsTestConfig.services.radicle.httpd.nginx;
                  inherit (cloudflareHttpsVhost) enableACME forceSSL listen;
                  firewallPorts = cloudflareHttpsTestConfig.networking.firewall.allowedTCPPorts;
                }
              )
            } >&2
            exit 1
          ''}
          ${lib.optionalString (!directAcmeHttpsPolicyValid) ''
            echo "direct-ACME HTTPS Git proxy transport does not activate its reviewed TLS boundary" >&2
            printf '%s\n' ${
              lib.escapeShellArg (
                builtins.toJSON {
                  httpdNginxServerName = directAcmeHttpsTestConfig.services.radicle.httpd.nginx.serverName;
                  inherit (directAcmeHttpsVhost) enableACME forceSSL listen;
                  firewallPorts = directAcmeHttpsTestConfig.networking.firewall.allowedTCPPorts;
                }
              )
            } >&2
            exit 1
          ''}
          ${lib.optionalString (!backupSourcePolicyValid) ''
            echo "Radicle backup source is not bounded to the reviewed encrypted job" >&2
            exit 1
          ''}
          ${lib.optionalString (!backupTargetPolicyValid) ''
            echo "Radicle backup target is not bounded to the reviewed dataset and restricted repository" >&2
            exit 1
          ''}
          ${lib.optionalString (!monitoringPolicyValid) ''
            echo "Radicle units are not covered by the admitted systemd monitoring path" >&2
            exit 1
          ''}
          ${lib.optionalString (failedAssertions != [ ]) ''
            echo "valid Radicle NixOS fixture has failed assertions:" >&2
            printf '%s\n' ${
              lib.escapeShellArg (lib.concatStringsSep "\n" (map (assertion: assertion.message) failedAssertions))
            } >&2
            exit 1
          ''}
          ${lib.optionalString (!(lib.hasInfix "--listen ${nodeAddress}:${toString nodePort}" nodeCommand)) ''
            echo "Radicle node does not bind the selected explicit address" >&2
            exit 1
          ''}
          ${lib.optionalString (!(lib.hasInfix "--listen=${httpAddress}:${toString httpPort}" httpdCommand))
            ''
              echo "Radicle HTTP daemon is not loopback-only" >&2
              exit 1
            ''
          }
          ${lib.optionalString (!(builtins.elem optionalPassphraseCredential nodeImportedCredentials)) ''
            echo "Radicle node lost the optional passphrase credential boundary" >&2
            exit 1
          ''}
          ${lib.optionalString (unexpectedNodeImports != [ ]) ''
            echo "Radicle node imports credentials outside its identity boundary" >&2
            exit 1
          ''}
          ${lib.optionalString (!(builtins.elem loadedPrivateKeyCredential nodeLoadedCredentials)) ''
            echo "Radicle node does not load the generated private key" >&2
            exit 1
          ''}
          ${lib.optionalString (unexpectedNodeLoads != [ ]) ''
            echo "Radicle node loads credentials outside its generated identity" >&2
            exit 1
          ''}
          ${lib.optionalString (httpdImportedCredentials != [ ] || httpdLoadedCredentials != [ ]) ''
            echo "Radicle HTTP daemon receives credentials" >&2
            exit 1
          ''}
          ${lib.optionalString (policyImportedCredentials != [ ] || policyLoadedCredentials != [ ]) ''
            echo "Radicle policy reconciler receives credentials" >&2
            exit 1
          ''}
          ${lib.optionalString (unexpectedSecretBindPaths != [ ]) ''
            echo "Radicle services bind a secret path other than the generated public key" >&2
            exit 1
          ''}
          ${lib.optionalString
            (
              !(
                builtins.elem expectedPublicKeyBind nodeBindPaths
                && builtins.elem expectedPublicKeyBind httpdBindPaths
              )
            )
            ''
              echo "Radicle services do not share the generated public identity" >&2
              exit 1
            ''
          }
          ${lib.optionalString (fixtureConfig.services.radicle.publicKey != publicKeyPath) ''
            echo "Radicle service does not consume the generated public identity" >&2
            exit 1
          ''}
          ${lib.optionalString
            (
              !(
                builtins.elem expectedPolicyConfigBind policyBindPaths
                && builtins.elem expectedPolicyPublicKeyBind policyBindPaths
              )
            )
            ''
              echo "Radicle policy reconciler cannot read the bounded public profile" >&2
              exit 1
            ''
          }
          ${lib.optionalString (!(lib.hasInfix policyReconcilerCommandPath policyCommand)) ''
            echo "Radicle policy service does not execute the reviewed reconciler" >&2
            exit 1
          ''}
          ${lib.optionalString (!(lib.hasInfix nodeRadCommandPath policyCommand)) ''
            echo "Radicle policy service does not use the reviewed Radicle CLI" >&2
            exit 1
          ''}
          ${lib.optionalString
            (
              !(lib.hasInfix productionPilotRepository policyCommand)
              || lib.hasInfix pinnedRepository policyCommand
            )
            ''
              echo "Radicle production policy does not admit exactly the reviewed pilot repository" >&2
              exit 1
            ''
          }
          ${lib.optionalString
            (
              builtins.attrNames productionHttpsLocations != productionExpectedLocationNames
              || productionHttpsLocations."/".return != 404
              || builtins.length productionHttpsVhost.listen != 1
              || (builtins.head productionHttpsVhost.listen).addr != httpsOriginAddress
              || (builtins.head productionHttpsVhost.listen).port != httpsOriginPort
              || (builtins.head productionHttpsVhost.listen).ssl
              ||
                productionCloudflareTunnel.ingress.${productionHttpsServerName}
                != "http://${httpsOriginAddress}:${toString httpsOriginPort}"
            )
            ''
              echo "Radicle production HTTPS policy is not the exact Cloudflare-only pilot route" >&2
              exit 1
            ''
          }
          ${lib.optionalString
            (
              !policyService.serviceConfig.PrivateNetwork
              || !(builtins.elem "/run/secrets" policyService.serviceConfig.InaccessiblePaths)
            )
            ''
              echo "Radicle policy reconciler can reach the network or host secrets" >&2
              exit 1
            ''
          }
          ${lib.optionalString
            (
              !(
                builtins.elem "radicle-node.service" policyService.requires
                && builtins.elem "radicle-httpd.service" policyService.requiredBy
                && builtins.elem "radicle-httpd.service" policyService.before
              )
            )
            ''
              echo "Radicle policy reconciliation is not ordered before HTTP service" >&2
              exit 1
            ''
          }
          ${lib.optionalString
            (
              policyTimer.timerConfig.OnBootSec != policyInitialDelay
              || policyTimer.timerConfig.OnUnitActiveSec != policyInterval
              || policyTimer.timerConfig.RandomizedDelaySec != policyJitter
              || policyTimer.timerConfig.Unit != "${policyServiceName}.service"
            )
            ''
              echo "Radicle policy reconciliation timer drifted" >&2
              exit 1
            ''
          }
          ${lib.optionalString (!(radicleServiceAbsent aspen2Config && radicleServiceAbsent aspen3Config)) ''
            echo "Radicle bootstrap service escaped Aspen1 onto an undeclared host" >&2
            exit 1
          ''}
          ${lib.optionalString
            (
              !(
                identityGeneratorAbsent aspen2Config
                && identityGeneratorAbsent aspen3Config
                && identityGeneratorAbsent desktopConfig
              )
            )
            ''
              echo "Radicle identity material escaped Aspen1" >&2
              exit 1
            ''
          }
          ${lib.optionalString
            (!(privateKeyFile.secret && privateKeyFile.deploy && !publicKeyFile.secret && publicKeyFile.deploy))
            ''
              echo "Radicle identity generator has unsafe secret/public deployment metadata" >&2
              exit 1
            ''
          }

          generator_out="$TMPDIR/generated-radicle-identity"
          mkdir -p "$generator_out"
          (
            export out="$generator_out"
            ${identityGenerator.script}
          )
          test "$(stat -c '%a' "$generator_out/${privateKeyFileName}")" = ${generatedPrivateKeyMode}
          test "$(stat -c '%a' "$generator_out/${publicKeyFileName}")" = ${generatedPublicKeyMode}
          ssh-keygen -y -f "$generator_out/${privateKeyFileName}" > "$TMPDIR/derived-public-key"
          cmp "$generator_out/${publicKeyFileName}" "$TMPDIR/derived-public-key"
          ${lib.optionalString (builtins.elem nodePort globalFirewallPorts) ''
            echo "Radicle peer port is globally exposed" >&2
            exit 1
          ''}
          ${lib.optionalString (!(builtins.elem nodePort interfaceFirewallPorts)) ''
            echo "Radicle peer port is absent from the selected interface" >&2
            exit 1
          ''}
          ${lib.optionalString (builtins.elem httpPort globalFirewallPorts) ''
            echo "Radicle HTTP daemon port is globally exposed" >&2
            exit 1
          ''}
          ${lib.optionalString (fixtureConfig.services.radicle.settings.node.seedingPolicy.default != "block")
            ''
              echo "Radicle node does not fail closed for unknown repositories" >&2
              exit 1
            ''
          }
          ${lib.optionalString (fixtureConfig.services.radicle.settings.node.relay != "always") ''
            echo "Radicle bootstrap node is not configured as a relay" >&2
            exit 1
          ''}
          ${lib.optionalString (fixtureConfig.services.radicle.settings.web.pinned.repositories != [ ]) ''
            echo "Radicle HTTP explorer pinned metadata drifted" >&2
            exit 1
          ''}
          ${lib.optionalString
            (
              nodeService.serviceConfig.User != "radicle"
              || httpdService.serviceConfig.User != "radicle"
              || policyService.serviceConfig.User != "radicle"
            )
            ''
              echo "Radicle services do not use the dedicated unprivileged account" >&2
              exit 1
            ''
          }
          ${lib.optionalString
            (!(nodeService.serviceConfig.PrivateDevices && httpdService.serviceConfig.PrivateDevices))
            ''
              echo "Radicle services can access host devices" >&2
              exit 1
            ''
          }
          ${lib.optionalString
            (
              !(
                nodeService.serviceConfig.MemoryDenyWriteExecute
                && httpdService.serviceConfig.MemoryDenyWriteExecute
              )
            )
            ''
              echo "Radicle services permit writable executable memory" >&2
              exit 1
            ''
          }
          ${lib.optionalString
            (!(nodeService.serviceConfig.NoNewPrivileges && httpdService.serviceConfig.NoNewPrivileges))
            ''
              echo "Radicle services can gain privileges" >&2
              exit 1
            ''
          }
          ${lib.optionalString
            (
              nodeService.serviceConfig.ProtectSystem != "strict"
              || httpdService.serviceConfig.ProtectSystem != "strict"
            )
            ''
              echo "Radicle services do not protect the host filesystem" >&2
              exit 1
            ''
          }
          ${lib.optionalString
            (
              nodeService.serviceConfig.StateDirectoryMode != privateStateDirectoryMode
              || httpdService.serviceConfig.StateDirectoryMode != privateStateDirectoryMode
            )
            ''
              echo "Radicle state is not private to the service account" >&2
              exit 1
            ''
          }

          touch "$out"
        '';
  };
}
