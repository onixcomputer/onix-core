# Verify that the module registry in services/contracts.ncl stays in
# sync with the actual module directories in modules/.
#
# Catches two kinds of drift:
#   - Module registered in contracts.ncl but no directory exists
#   - Module directory exists (and is in modules/default.nix) but not
#     registered in contracts.ncl
#
# Note: borgbackup-extras and matrix-synapse-cf are plain NixOS modules
# loaded via extraModules, not clan perInstance service definitions.
# They are intentionally absent from the registry.
{
  self,
  pkgs,
  lib,
  ...
}:
let
  plugins = self.packages.x86_64-linux.wasm-plugins;
  wasm = import ../lib/wasm.nix { inherit plugins; };

  moduleLists = wasm.evalNickelFile ../inventory/services/module-lists.ncl;
  llamacppServerValidation = wasm.evalNickelFile ../inventory/services/fixtures/llamacpp-server-validation.ncl;
  sglangDiffusionValidation = wasm.evalNickelFile ../inventory/services/fixtures/sglang-diffusion-validation.ncl;
  ttInferenceServerValidation = wasm.evalNickelFile ../inventory/services/fixtures/tt-inference-server-validation.ncl;
  rustfsValidation = wasm.evalNickelFile ../inventory/services/fixtures/rustfs-validation.ncl;
  rustfsTopologyTests = import ../modules/rustfs/topology-tests.nix { inherit lib; };
  rustfsBackupSettingsTests = import ../modules/rustfs/backup-settings-tests.nix { inherit lib; };
  rustfsBucketPolicyTests = import ../lib/rustfs-bucket-policy-tests.nix { inherit lib; };
  celldValidation = wasm.evalNickelFile ../inventory/services/fixtures/celld-validation.ncl;
  celldSettingsTests = import ../modules/celld/settings-tests.nix { inherit lib; };
  bookshelfValidation = wasm.evalNickelFile ../inventory/services/fixtures/bookshelf-validation.ncl;
  bookshelfSettingsTests = import ../modules/bookshelf/settings-tests.nix { inherit lib; };
  kacheRustfsValidation = wasm.evalNickelFile ../inventory/services/fixtures/kache-rustfs-validation.ncl;
  kacheRustfsSettingsTests = import ../modules/kache-rustfs/settings-tests.nix { inherit lib; };
  niks3Validation = wasm.evalNickelFile ../inventory/services/fixtures/niks3-validation.ncl;
  niks3SettingsTests = import ../modules/niks3/settings-tests.nix { inherit lib; };

  # Modules registered in contracts.ncl (clan perInstance services only)
  registeredModules = lib.sort lib.lessThan moduleLists.selfModules;

  # Module directories on disk that are clan perInstance services
  # (i.e., listed in modules/default.nix).
  moduleDefs = import ../modules { inherit (self) inputs; };
  diskModules = lib.sort lib.lessThan (lib.attrNames moduleDefs);

  inRegistryNoDisk = lib.subtractLists diskModules registeredModules;
  onDiskNoRegistry = lib.subtractLists registeredModules diskModules;

  # Modules missing schema.ncl files
  modulesWithoutSchema = builtins.filter (
    name: !builtins.pathExists (self + "/modules/${name}/schema.ncl")
  ) diskModules;

  llamacppPositiveErrors = llamacppServerValidation.positive;
  llamacppNegativeErrors = llamacppServerValidation.negative;
  expectedLlamacppNegativeFields = [
    "backend"
    "modelSha256"
    "metaliumDeviceId"
    "metaliumInspectorPort"
    "metaliumTrace"
    "generationThreads"
    "batchThreads"
    "flashAttention"
  ];
  missingLlamacppNegativeFields = builtins.filter (
    field: !(lib.any (error: lib.hasInfix field error) llamacppNegativeErrors)
  ) expectedLlamacppNegativeFields;

  sglangPositiveErrors = sglangDiffusionValidation.positive;
  sglangNegativeErrors = sglangDiffusionValidation.negative;
  expectedSglangNegativeFields = [
    "port"
    "numGpus"
    "gpuPassthrough"
    "environmentFiles"
  ];
  missingSglangNegativeFields = builtins.filter (
    field: !(lib.any (error: lib.hasInfix field error) sglangNegativeErrors)
  ) expectedSglangNegativeFields;

  ttInferenceServerPositiveErrors = ttInferenceServerValidation.positive;
  ttInferenceServerNegativeErrors = ttInferenceServerValidation.negative;
  expectedTtInferenceServerNegativeFields = [
    "image"
    "model"
    "device"
    "physicalDeviceId"
    "host"
    "port"
    "cacheUid"
    "cacheGid"
    "enableTraceCapture"
    "autoStart"
    "extraArgs"
  ];
  missingTtInferenceServerNegativeFields = builtins.filter (
    field: !(lib.any (error: lib.hasInfix field error) ttInferenceServerNegativeErrors)
  ) expectedTtInferenceServerNegativeFields;

  rustfsPositiveErrors = rustfsValidation.positive ++ rustfsValidation.backup_positive;
  rustfsNegativeErrors = rustfsValidation.negative ++ rustfsValidation.backup_negative;
  expectedRustfsNegativeFields = [
    "mode"
    "serviceName"
    "dataDir"
    "bindAddress"
    "apiPort"
    "consolePort"
    "enableConsole"
    "openFirewall"
    "firewallInterface"
    "clusterEndpoints"
    "topologyWaitMode"
    "topologyWaitTimeoutSeconds"
    "cpuWeight"
    "ioWeight"
    "nice"
    "oomScoreAdjust"
    "sourceEndpoint"
    "buckets"
    "targetDir"
    "schedule"
    "retentionDays"
    "adminGenerator"
    "restoreProbeBucket"
  ];
  missingRustfsNegativeFields = builtins.filter (
    field: !(lib.any (error: lib.hasInfix field error) rustfsNegativeErrors)
  ) expectedRustfsNegativeFields;
  rustfsTopologyPositiveErrors = rustfsTopologyTests.positiveErrors;
  rustfsTopologyMissingNegativeCases = rustfsTopologyTests.missingNegativeCases;
  rustfsTopologyNegativeErrors = rustfsTopologyTests.negativeErrors;
  rustfsBackupPositiveErrors = rustfsBackupSettingsTests.positiveErrors;
  rustfsBackupMissingNegativeCases = rustfsBackupSettingsTests.missingNegativeCases;
  rustfsClusterMachines = [
    "aspen1"
    "aspen3"
    "britton-desktop"
  ];
  rustfsMissingNetlinkMachines = builtins.filter (
    machine:
    !(builtins.elem "AF_NETLINK"
      self.nixosConfigurations.${machine}.config.systemd.services.rustfs.serviceConfig.RestrictAddressFamilies
    )
  ) rustfsClusterMachines;
  rustfsBackupTargetDir = "/datapool/rustfs-authority-backup";
  rustfsBackupServiceName = "rustfs-authority-backup-rustfs-cluster";
  rustfsRestoreServiceName = "rustfs-authority-restore-probe-rustfs-cluster";
  rustfsDesktopConfig = self.nixosConfigurations.britton-desktop.config;
  rustfsBackupService = rustfsDesktopConfig.systemd.services.${rustfsBackupServiceName};
  rustfsRestoreService = rustfsDesktopConfig.systemd.services.${rustfsRestoreServiceName};
  rustfsBackupGeneratedValid =
    builtins.hasAttr rustfsBackupServiceName rustfsDesktopConfig.systemd.services
    && builtins.hasAttr rustfsRestoreServiceName rustfsDesktopConfig.systemd.services
    && builtins.hasAttr rustfsBackupServiceName rustfsDesktopConfig.systemd.timers
    && builtins.elem rustfsBackupTargetDir rustfsBackupService.unitConfig.RequiresMountsFor
    && builtins.elem rustfsBackupTargetDir rustfsRestoreService.unitConfig.RequiresMountsFor
    && rustfsRestoreService.serviceConfig.ReadOnlyPaths == [ rustfsBackupTargetDir ];

  celldPositiveErrors = celldValidation.positive;
  celldNegativeErrors = celldValidation.negative;
  expectedCelldNegativeFields = [
    "runtimeName"
    "stateDir"
    "bindAddress"
    "storageEndpoint"
    "bucketName"
    "region"
    "accessKeyId"
    "publisherUser"
    "publicPort"
    "internalPort"
    "stripTrailingSlashProxy"
    "backendAddress"
    "backendPort"
    "openFirewall"
    "firewallInterface"
    "provisionStorage"
    "rustfsAdminGenerator"
    "deployCounter"
    "leaseTtlMilliseconds"
    "restartDelaySeconds"
    "shutdownDrainMilliseconds"
  ];
  missingCelldNegativeFields = builtins.filter (
    field: !(lib.any (error: lib.hasInfix field error) celldNegativeErrors)
  ) expectedCelldNegativeFields;
  celldSettingsPositiveErrors = celldSettingsTests.positiveErrors;
  celldSettingsMissingNegativeCases = celldSettingsTests.missingNegativeCases;
  celldSettingsNegativeErrors = celldSettingsTests.negativeErrors;
  celldPublicPort = 39200;
  celldInternalPort = 39201;
  celldClusterMachines = [
    "aspen1"
    "aspen3"
    "britton-desktop"
  ];
  celldProvisionerMachines = builtins.filter (
    machine:
    builtins.hasAttr "celld-storage-provision"
      self.nixosConfigurations.${machine}.config.systemd.services
  ) celldClusterMachines;
  celldMissingServices = builtins.filter (
    machine: !(builtins.hasAttr "celld" self.nixosConfigurations.${machine}.config.systemd.services)
  ) celldClusterMachines;
  celldExpectedStorageEndpoints = {
    aspen1 = "http://100.100.103.95:39000";
    aspen3 = "http://100.108.13.4:39000";
    britton-desktop = "http://100.110.43.11:39000";
  };
  celldStorageEndpointMismatches = builtins.filter (
    machine:
    self.nixosConfigurations.${machine}.config.systemd.services.celld.environment.S3_ENDPOINT
    != celldExpectedStorageEndpoints.${machine}
  ) celldClusterMachines;
  celldTailnetFirewallMismatches = builtins.filter (
    machine:
    let
      firewall = self.nixosConfigurations.${machine}.config.networking.firewall;
      tailnetPorts = firewall.interfaces.tailscale0.allowedTCPPorts;
      globalPorts = firewall.allowedTCPPorts;
      requiredPorts = [
        celldPublicPort
        celldInternalPort
      ];
    in
    !(lib.all (port: builtins.elem port tailnetPorts) requiredPorts)
    || lib.any (port: builtins.elem port globalPorts) requiredPorts
  ) celldClusterMachines;
  celldDesktopClockProviderValid =
    self.nixosConfigurations.britton-desktop.config.services.chrony.enable
    && !self.nixosConfigurations.britton-desktop.config.services.timesyncd.enable;

  siteCelldPublicPort = 32110;
  siteCelldInternalPort = 32111;
  siteCelldBackendPort = 32112;
  siteCelldPortsAvoidEphemeralRange =
    siteCelldPublicPort < 32768 && siteCelldInternalPort < 32768 && siteCelldBackendPort < 32768;
  siteCelldServiceName = "celld-site";
  siteCelldIngressServiceName = "celld-site-ingress";
  siteCelldProvisionServiceName = "celld-site-storage-provision";
  siteCelldBucketUri = "s3://onix-site-celld";
  siteCelldMachines = [
    "aspen3"
    "britton-desktop"
  ];
  siteCelldProvisionerMachines = builtins.filter (
    machine:
    builtins.hasAttr siteCelldProvisionServiceName
      self.nixosConfigurations.${machine}.config.systemd.services
  ) siteCelldMachines;
  siteCelldMissingServices = builtins.filter (
    machine:
    !(builtins.hasAttr siteCelldServiceName self.nixosConfigurations.${machine}.config.systemd.services)
  ) siteCelldMachines;
  siteCelldMissingIngressServices = builtins.filter (
    machine:
    !(builtins.hasAttr siteCelldIngressServiceName
      self.nixosConfigurations.${machine}.config.systemd.services
    )
  ) siteCelldMachines;
  siteCelldExpectedBackendListeners = {
    aspen3 = "127.0.0.1:${toString siteCelldBackendPort}";
    britton-desktop = "127.0.0.1:${toString siteCelldBackendPort}";
  };
  siteCelldBackendListenerMismatches = builtins.filter (
    machine:
    self.nixosConfigurations.${machine}.config.systemd.services.${siteCelldServiceName}.environment.CELLD_ADDR
    != siteCelldExpectedBackendListeners.${machine}
  ) siteCelldMachines;
  siteCelldExpectedStorageEndpoints = {
    aspen3 = "http://100.108.13.4:39000";
    britton-desktop = "http://100.110.43.11:39000";
  };
  siteCelldStorageEndpointMismatches = builtins.filter (
    machine:
    self.nixosConfigurations.${machine}.config.systemd.services.${siteCelldServiceName}.environment.S3_ENDPOINT
    != siteCelldExpectedStorageEndpoints.${machine}
  ) siteCelldMachines;
  siteCelldBucketMismatches = builtins.filter (
    machine:
    self.nixosConfigurations.${machine}.config.systemd.services.${siteCelldServiceName}.environment.CELLD_BUCKET
    != siteCelldBucketUri
  ) siteCelldMachines;
  siteCelldIsolationMismatches = builtins.filter (
    machine:
    let
      services = self.nixosConfigurations.${machine}.config.systemd.services;
      labService = services.celld;
      siteService = services.${siteCelldServiceName};
    in
    labService.serviceConfig.User == siteService.serviceConfig.User
    || labService.serviceConfig.WorkingDirectory == siteService.serviceConfig.WorkingDirectory
    || labService.environment.CELLD_BUCKET == siteService.environment.CELLD_BUCKET
  ) siteCelldMachines;
  siteCelldTailnetFirewallMismatches = builtins.filter (
    machine:
    let
      firewall = self.nixosConfigurations.${machine}.config.networking.firewall;
      requiredPorts = [
        siteCelldPublicPort
        siteCelldInternalPort
      ];
    in
    !(lib.all (port: builtins.elem port firewall.interfaces.tailscale0.allowedTCPPorts) requiredPorts)
    || builtins.elem siteCelldBackendPort firewall.interfaces.tailscale0.allowedTCPPorts
    || lib.any (port: builtins.elem port firewall.allowedTCPPorts) (
      requiredPorts ++ [ siteCelldBackendPort ]
    )
  ) siteCelldMachines;
  siteCelldPublisherCredential =
    self.nixosConfigurations.britton-desktop.config.clan.core.vars.generators.celld-site-celld.files."publisher-aws-env";
  siteCelldPublisherCredentialValid =
    siteCelldPublisherCredential.secret
    && siteCelldPublisherCredential.deploy
    && siteCelldPublisherCredential.owner == "brittonr"
    && siteCelldPublisherCredential.group == siteCelldServiceName
    && siteCelldPublisherCredential.mode == "0400";
  celldLabPublisherCredentialAbsent =
    !(builtins.hasAttr "publisher-aws-env" self.nixosConfigurations.britton-desktop.config.clan.core.vars.generators.celld-celld-lab.files);

  bookshelfPositiveErrors = bookshelfValidation.positive;
  bookshelfNegativeErrors = bookshelfValidation.negative;
  expectedBookshelfNegativeFields = [
    "sourceDir"
    "libraryDir"
    "bindAddress"
    "port"
    "siteUrl"
    "readOnly"
    "openFirewall"
    "firewallInterface"
    "restartDelaySeconds"
  ];
  missingBookshelfNegativeFields = builtins.filter (
    field: !(lib.any (error: lib.hasInfix field error) bookshelfNegativeErrors)
  ) expectedBookshelfNegativeFields;
  bookshelfSettingsPositiveErrors = bookshelfSettingsTests.positiveErrors;
  bookshelfSettingsMissingNegativeCases = bookshelfSettingsTests.missingNegativeCases;
  bookshelfSettingsNegativeErrors = bookshelfSettingsTests.negativeErrors;
  bookshelfPort = 39300;
  bookshelfAddress = "100.110.43.11";
  bookshelfLibraryDirectory = "/datapool/bookshelf/library";
  bookshelfSourceDirectory = "/datapool/bookshelf/source";
  bookshelfRuntimeDirectory = "bookshelf";
  bookshelfRuntimeRoot = "/run/${bookshelfRuntimeDirectory}";
  bookshelfDesktopConfig = self.nixosConfigurations.britton-desktop.config;
  bookshelfService = bookshelfDesktopConfig.systemd.services.bookshelf;
  bookshelfPublishServicePresent = builtins.hasAttr "bookshelf-publish" bookshelfDesktopConfig.systemd.services;
  bookshelfImportTools = builtins.filter (
    package: lib.getName package == "bookshelf-import"
  ) bookshelfDesktopConfig.environment.systemPackages;
  bookshelfImportToolPresent = builtins.length bookshelfImportTools == 1;
  bookshelfEnvironmentValid =
    bookshelfService.environment.BOOKSHELF_PROVIDER == "fs"
    && bookshelfService.environment.BOOKSHELF_DIRECTORY == bookshelfLibraryDirectory
    && bookshelfService.environment.HOSTNAME == bookshelfAddress
    && bookshelfService.environment.PORT == toString bookshelfPort;
  bookshelfSandboxValid =
    bookshelfService.serviceConfig.User == "bookshelf"
    && bookshelfService.serviceConfig.Group == "bookshelf"
    && bookshelfService.serviceConfig.ProtectSystem == "strict"
    && bookshelfService.serviceConfig.RuntimeDirectory == bookshelfRuntimeDirectory
    && bookshelfService.serviceConfig.WorkingDirectory == bookshelfRuntimeRoot
    && builtins.elem bookshelfLibraryDirectory bookshelfService.serviceConfig.ReadWritePaths;
  bookshelfTailnetFirewallValid =
    builtins.elem bookshelfPort bookshelfDesktopConfig.networking.firewall.interfaces.tailscale0.allowedTCPPorts
    && !(builtins.elem bookshelfPort bookshelfDesktopConfig.networking.firewall.allowedTCPPorts);
  bookshelfPrivateDirectoriesValid =
    builtins.elem "d ${bookshelfSourceDirectory} 0700 bookshelf bookshelf -" bookshelfDesktopConfig.systemd.tmpfiles.rules
    && builtins.elem "d ${bookshelfLibraryDirectory} 0700 bookshelf bookshelf -" bookshelfDesktopConfig.systemd.tmpfiles.rules;

  kacheRustfsPositiveErrors = kacheRustfsValidation.positive;
  kacheRustfsNegativeErrors = kacheRustfsValidation.negative;
  expectedKacheRustfsNegativeFields = [
    "cacheDir"
    "cacheMaxSize"
    "serviceUser"
    "storageEndpoint"
    "bucketName"
    "region"
    "prefix"
    "accessKeyId"
    "provisionStorage"
    "rustfsAdminGenerator"
    "restartDelaySeconds"
  ];
  missingKacheRustfsNegativeFields = builtins.filter (
    field: !(lib.any (error: lib.hasInfix field error) kacheRustfsNegativeErrors)
  ) expectedKacheRustfsNegativeFields;
  kacheRustfsSemanticPositiveErrors = kacheRustfsSettingsTests.positiveErrors;
  kacheRustfsMissingNegativeCases = kacheRustfsSettingsTests.missingNegativeCases;

  niks3PositiveErrors = niks3Validation.server_positive ++ niks3Validation.uploader_positive;
  niks3NegativeErrors = niks3Validation.server_negative ++ niks3Validation.uploader_negative;
  expectedNiks3NegativeFields = [
    "bindAddress"
    "port"
    "storageEndpoint"
    "storageServiceName"
    "bucketName"
    "region"
    "accessKeyId"
    "provisionStorage"
    "rustfsAdminGenerator"
    "openFirewall"
    "firewallInterface"
    "gcOlderThan"
    "gcFailedUploadsOlderThan"
    "gcSchedule"
    "maxNarSize"
    "metadataBackupEnabled"
    "metadataBackupEndpoint"
    "metadataBackupBucket"
    "metadataBackupAccessKeyId"
    "metadataBackupAdminGenerator"
    "metadataBackupDirectory"
    "metadataBackupSchedule"
    "serverUrl"
    "automaticUploads"
    "maintenanceMarker"
    "maintenanceGuardUrls"
    "batchSize"
    "idleExitTimeoutSeconds"
    "maxConcurrentUploads"
    "verifyS3Integrity"
  ];
  missingNiks3NegativeFields = builtins.filter (
    field: !(lib.any (error: lib.hasInfix field error) niks3NegativeErrors)
  ) expectedNiks3NegativeFields;
  niks3SemanticPositiveErrors = niks3SettingsTests.positiveErrors;
  niks3MissingNegativeCases = niks3SettingsTests.missingNegativeCases;

  kacheRustfsMachines = [
    "aspen1"
    "aspen3"
    "britton-desktop"
  ];
  kacheRustfsSystemConfigPath = "/etc/kache-rustfs/config.toml";
  kacheRustfsExpected = {
    aspen1 = {
      cacheDir = "/var/cache/kache-nix/user-brittonr";
      endpoint = "http://100.100.103.95:39000";
    };
    aspen3 = {
      cacheDir = "/mnt/usb4-nvme/kache-nix/user-brittonr";
      endpoint = "http://100.108.13.4:39000";
    };
    britton-desktop = {
      cacheDir = "/var/cache/kache-nix/user-brittonr";
      endpoint = "http://100.110.43.11:39000";
    };
  };
  kacheRustfsFleetErrors =
    nodes:
    let
      machineNames = map (node: node.machine) nodes;
      missingMachines = builtins.filter (
        machine: !(builtins.elem machine machineNames)
      ) kacheRustfsMachines;
      extraMachines = builtins.filter (
        machine: !(builtins.elem machine kacheRustfsMachines)
      ) machineNames;
      provisioners = builtins.filter (node: node.provisions) nodes;
    in
    lib.optional (missingMachines != [ ]) "Kache fleet is missing required machines"
    ++ lib.optional (extraMachines != [ ]) "Kache fleet contains unexpected machines"
    ++ lib.optional (
      builtins.length provisioners != 1
    ) "Kache fleet must contain exactly one storage provisioner";
  kacheRustfsPositiveFleetErrors = kacheRustfsFleetErrors [
    {
      machine = "aspen1";
      provisions = false;
    }
    {
      machine = "aspen3";
      provisions = false;
    }
    {
      machine = "britton-desktop";
      provisions = true;
    }
  ];
  kacheRustfsMissingMachineErrors = kacheRustfsFleetErrors [
    {
      machine = "aspen1";
      provisions = false;
    }
    {
      machine = "britton-desktop";
      provisions = true;
    }
  ];
  kacheRustfsMultipleProvisionerErrors = kacheRustfsFleetErrors [
    {
      machine = "aspen1";
      provisions = true;
    }
    {
      machine = "aspen3";
      provisions = false;
    }
    {
      machine = "britton-desktop";
      provisions = true;
    }
  ];
  kacheRustfsProvisioners = builtins.filter (
    machine:
    builtins.hasAttr "kache-rustfs-storage-provision"
      self.nixosConfigurations.${machine}.config.systemd.services
  ) kacheRustfsMachines;
  kacheRustfsMismatches = builtins.filter (
    machine:
    let
      machineConfig = self.nixosConfigurations.${machine}.config;
      expected = kacheRustfsExpected.${machine};
      service = machineConfig.systemd.services.kache-rustfs;
      credentialGenerator = machineConfig.clan.core.vars.generators.kache-rustfs-kache-remote;
      credential = credentialGenerator.files."aws-env";
      homeConfig = machineConfig.home-manager.users.brittonr;
      generatedConfig = builtins.readFile machineConfig.environment.etc."kache-rustfs/config.toml".source;
      syncTools = builtins.filter (
        package: lib.getName package == "kache-rustfs-sync"
      ) machineConfig.environment.systemPackages;
      expectedTmpfilesRule = "d ${expected.cacheDir} 0700 brittonr users -";
    in
    service.serviceConfig.User != "brittonr"
    || service.serviceConfig.ProtectSystem != "strict"
    || service.serviceConfig.Restart != "always"
    || !(lib.hasInfix "daemon stop" (toString service.serviceConfig.ExecStartPre))
    || service.environment.KACHE_CONFIG != kacheRustfsSystemConfigPath
    || service.environment.KACHE_CACHE_DIR != expected.cacheDir
    || service.environment.KACHE_LOCAL_ONLY != "0"
    || !credentialGenerator.share
    || credential.owner != "brittonr"
    || credential.mode != "0400"
    || builtins.length syncTools != 1
    || !(builtins.elem expectedTmpfilesRule machineConfig.systemd.tmpfiles.rules)
    || !(lib.hasInfix "local_store = \"${expected.cacheDir}\"" generatedConfig)
    || !(lib.hasInfix "local_max_size = \"32GiB\"" generatedConfig)
    || !(lib.hasInfix "prefetch_enabled = false" generatedConfig)
    || !(lib.hasInfix "endpoint = \"${expected.endpoint}\"" generatedConfig)
    || homeConfig.home.sessionVariables.KACHE_CONFIG != kacheRustfsSystemConfigPath
    || !(builtins.hasAttr ".cargo/config.toml" homeConfig.home.file)
    || builtins.hasAttr "kache" homeConfig.systemd.user.services
  ) kacheRustfsMachines;
  kacheRustfsGeneratedValid =
    kacheRustfsPositiveFleetErrors == [ ]
    && lib.any (error: lib.hasInfix "missing required machines" error) kacheRustfsMissingMachineErrors
    && lib.any (
      error: lib.hasInfix "exactly one storage provisioner" error
    ) kacheRustfsMultipleProvisionerErrors
    && kacheRustfsProvisioners == [ "britton-desktop" ]
    && kacheRustfsMismatches == [ ];

  niks3Port = 39400;
  niks3StoragePort = 39500;
  niks3StorageAddress = "100.100.103.95";
  niks3StorageDataDir = "/var/lib/rustfs-niks3-cache";
  niks3StorageResourceWeight = 10;
  niks3MaintenanceMarker = "/run/niks3-maintenance-window";
  niks3ServerUrl = "http://100.100.103.95:${toString niks3Port}";
  niks3UploadBatchSize = 1;
  niks3MaxConcurrentUploads = 1;
  niks3BucketName = "onix-niks3";
  niks3PublicKeyPrefix = "onix-niks3-1:";
  niks3Machines = [
    "aspen1"
    "aspen3"
    "britton-desktop"
  ];
  niks3Aspen1 = self.nixosConfigurations.aspen1.config;
  niks3ServerSettings = niks3Aspen1.services.niks3;
  niks3StorageUnit = niks3Aspen1.systemd.services.rustfs-niks3-cache;
  niks3Provisioners = builtins.filter (
    machine:
    builtins.hasAttr "niks3-storage-provision"
      self.nixosConfigurations.${machine}.config.systemd.services
  ) niks3Machines;
  niks3UploaderMismatches = builtins.filter (
    machine:
    let
      machineConfig = self.nixosConfigurations.${machine}.config;
    in
    !(builtins.hasAttr "niks3-auto-upload" machineConfig.systemd.services)
    || machineConfig.services."niks3-auto-upload".batchSize != niks3UploadBatchSize
    || machineConfig.services."niks3-auto-upload".maxConcurrentUploads != niks3MaxConcurrentUploads
    || machineConfig.systemd.sockets.niks3-auto-upload.wantedBy != [ ]
    ||
      machineConfig.systemd.services.niks3-auto-upload.unitConfig.ConditionPathExists
      != niks3MaintenanceMarker
    || !(lib.hasInfix "niks3-post-build-upload-disabled" (
      toString machineConfig.nix.settings.post-build-hook
    ))
    || !(builtins.elem niks3ServerUrl machineConfig.nix.settings.extra-substituters)
    || !(lib.any (
      key: lib.hasPrefix niks3PublicKeyPrefix key
    ) machineConfig.nix.settings.extra-trusted-public-keys)
  ) niks3Machines;
  niks3FirewallValid =
    builtins.elem niks3Port niks3Aspen1.networking.firewall.interfaces.tailscale0.allowedTCPPorts
    && builtins.elem niks3StoragePort niks3Aspen1.networking.firewall.interfaces.tailscale0.allowedTCPPorts
    && !(builtins.elem niks3Port niks3Aspen1.networking.firewall.allowedTCPPorts)
    && !(builtins.elem niks3StoragePort niks3Aspen1.networking.firewall.allowedTCPPorts);
  niks3ServerGeneratedValid =
    niks3ServerSettings.enable
    && niks3ServerSettings.package.version == "1.8.0"
    && niks3ServerSettings.httpAddr == "100.100.103.95:${toString niks3Port}"
    && niks3ServerSettings.s3.bucket == niks3BucketName
    && niks3ServerSettings.s3.endpoint == "${niks3StorageAddress}:${toString niks3StoragePort}"
    && niks3ServerSettings.s3.bucketLookup == "path"
    && !niks3ServerSettings.s3.useSSL
    && niks3ServerSettings.readProxy.enable
    && niks3Aspen1.systemd.services.niks3.serviceConfig.User == "niks3"
    && niks3Aspen1.systemd.services.niks3.serviceConfig.CPUWeight == niks3StorageResourceWeight
    && niks3Aspen1.systemd.services.niks3.serviceConfig.IOWeight == niks3StorageResourceWeight
    &&
      niks3StorageUnit.environment.RUSTFS_ADDRESS == "${niks3StorageAddress}:${toString niks3StoragePort}"
    && niks3StorageUnit.environment.RUSTFS_VOLUMES == niks3StorageDataDir
    && niks3StorageUnit.serviceConfig.ReadWritePaths == [ niks3StorageDataDir ]
    && niks3StorageUnit.serviceConfig.CPUWeight == niks3StorageResourceWeight
    && niks3StorageUnit.serviceConfig.IOWeight == niks3StorageResourceWeight;
  niks3StorageCredentialFiles = niks3Aspen1.clan.core.vars.generators.niks3-nix-cache-storage.files;
  niks3CredentialsValid =
    niks3StorageCredentialFiles."access-key".owner == "niks3"
    && niks3StorageCredentialFiles."access-key".mode == "0400"
    && niks3StorageCredentialFiles."secret-key".owner == "niks3"
    && niks3StorageCredentialFiles."signing-key".owner == "niks3";
  niks3MetadataBackupCredential =
    niks3Aspen1.clan.core.vars.generators."niks3-nix-cache-metadata-backup".files."aws-env";
  niks3MetadataBackupValid =
    niks3Aspen1.services.postgresqlBackup.enable
    && niks3Aspen1.services.postgresqlBackup.databases == [ "niks3" ]
    && niks3Aspen1.services.postgresqlBackup.location == "/var/backup/niks3"
    && builtins.hasAttr "niks3-metadata-backup-provision" niks3Aspen1.systemd.services
    && builtins.hasAttr "niks3-metadata-backup-upload" niks3Aspen1.systemd.services
    &&
      builtins.elem "niks3-metadata-backup-upload.service"
        niks3Aspen1.systemd.services."postgresqlBackup-niks3".unitConfig.OnSuccess
    && niks3MetadataBackupCredential.mode == "0400";
  niks3QueueMetricMismatches = builtins.filter (
    machine:
    let
      machineConfig = self.nixosConfigurations.${machine}.config;
    in
    !(builtins.hasAttr "niks3-queue-metrics" machineConfig.systemd.services)
    || !(builtins.hasAttr "niks3-queue-metrics" machineConfig.systemd.timers)
    || !(builtins.elem "--collector.textfile.directory=/var/lib/prometheus-node-exporter-text-files" machineConfig.services.prometheus.exporters.node.extraFlags)
  ) niks3Machines;
  storageMonitoringConfig = self.nixosConfigurations.britton-desktop.config;
  storageMonitoringRules = lib.concatStringsSep "\n" storageMonitoringConfig.services.prometheus.rules;
  storageMonitoringValid =
    storageMonitoringConfig.services.prometheus.exporters.blackbox.enable
    && storageMonitoringConfig.services.prometheus.exporters.blackbox.listenAddress == "127.0.0.1"
    && lib.any (
      scrape: scrape.job_name == "storage-coordination-health"
    ) storageMonitoringConfig.services.prometheus.scrapeConfigs
    && lib.hasInfix "Niks3UploadQueueCritical" storageMonitoringRules
    && lib.hasInfix "StorageCoordinationProbeFailed" storageMonitoringRules
    && lib.hasInfix "StorageCoordinationProbeSlow" storageMonitoringRules
    && lib.hasInfix "BuildStorageLowCapacity" storageMonitoringRules;
in
{
  checks = {
    module-registry-sync = pkgs.runCommand "module-registry-sync" { } ''
      ${lib.optionalString (inRegistryNoDisk != [ ]) ''
        echo "Modules in contracts.ncl selfModules but missing from modules/default.nix:"
        echo "  ${lib.concatStringsSep " " inRegistryNoDisk}"
        echo ""
      ''}
      ${lib.optionalString (onDiskNoRegistry != [ ]) ''
        echo "Modules in modules/default.nix but not registered in contracts.ncl:"
        echo "  ${lib.concatStringsSep " " onDiskNoRegistry}"
        echo ""
      ''}
      ${lib.optionalString (modulesWithoutSchema != [ ]) ''
        echo "Modules missing schema.ncl (needed for settings contract validation):"
        echo "  ${lib.concatStringsSep " " modulesWithoutSchema}"
        echo ""
      ''}
      ${lib.optionalString
        (inRegistryNoDisk != [ ] || onDiskNoRegistry != [ ] || modulesWithoutSchema != [ ])
        ''
          echo "Fix: update contracts.ncl and/or add schema.ncl to each module"
          exit 1
        ''
      }
      touch $out
    '';

    # Positive and negative settings coverage for
    # r[verify onix.tenstorrent.model_process_isolation.devices] and
    # r[verify onix.tenstorrent.model_performance.trace_replay].
    llamacpp-server-settings = pkgs.runCommand "llamacpp-server-settings" { } ''
      ${lib.optionalString (llamacppPositiveErrors != [ ]) ''
        echo "Valid llamacpp-server settings produced unexpected errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" llamacppPositiveErrors)}
        exit 1
      ''}
      ${lib.optionalString (missingLlamacppNegativeFields != [ ]) ''
        echo "Invalid llamacpp-server settings did not report expected fields:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" missingLlamacppNegativeFields)}
        echo "Actual errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" llamacppNegativeErrors)}
        exit 1
      ''}
      touch $out
    '';

    sglang-diffusion-settings = pkgs.runCommand "sglang-diffusion-settings" { } ''
      ${lib.optionalString (sglangPositiveErrors != [ ]) ''
        echo "Valid sglang-diffusion settings produced unexpected errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" sglangPositiveErrors)}
        exit 1
      ''}
      ${lib.optionalString (missingSglangNegativeFields != [ ]) ''
        echo "Invalid sglang-diffusion settings did not report expected fields:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" missingSglangNegativeFields)}
        echo "Actual errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" sglangNegativeErrors)}
        exit 1
      ''}
      touch $out
    '';

    # Positive and negative settings coverage for
    # r[verify onix.tenstorrent.vllm.p150_llama] and
    # r[verify onix.tenstorrent.vllm.secrets].
    tt-inference-server-settings = pkgs.runCommand "tt-inference-server-settings" { } ''
      ${lib.optionalString (ttInferenceServerPositiveErrors != [ ]) ''
        echo "Valid tt-inference-server settings produced unexpected errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" ttInferenceServerPositiveErrors)}
        exit 1
      ''}
      ${lib.optionalString (missingTtInferenceServerNegativeFields != [ ]) ''
        echo "Invalid tt-inference-server settings did not report expected fields:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" missingTtInferenceServerNegativeFields)}
        echo "Actual errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" ttInferenceServerNegativeErrors)}
        exit 1
      ''}
      touch $out
    '';

    rustfs-settings = pkgs.runCommand "rustfs-settings" { } ''
      ${lib.optionalString (rustfsPositiveErrors != [ ]) ''
        echo "Valid rustfs settings produced unexpected errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" rustfsPositiveErrors)}
        exit 1
      ''}
      ${lib.optionalString (missingRustfsNegativeFields != [ ]) ''
        echo "Invalid rustfs settings did not report expected fields:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" missingRustfsNegativeFields)}
        echo "Actual errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" rustfsNegativeErrors)}
        exit 1
      ''}
      ${lib.optionalString (rustfsBackupPositiveErrors != [ ]) ''
        echo "Valid RustFS backup settings produced semantic errors"
        exit 1
      ''}
      ${lib.optionalString (rustfsBackupMissingNegativeCases != [ ]) ''
        echo "Invalid RustFS backup settings did not report expected semantic errors"
        exit 1
      ''}
      touch $out
    '';

    # r[verify onix.rustfs_build_caches.recovery]
    rustfs-backup-generated = pkgs.runCommand "rustfs-backup-generated" { } ''
      ${lib.optionalString (!rustfsBackupGeneratedValid) ''
        echo "RustFS authority backup or restore units drifted"
        exit 1
      ''}
      grep -Fq -- '! -name MANIFEST.b3' ${rustfsBackupService.serviceConfig.ExecStart}
      ! grep -Fq -- 'find . -type f -print0' ${rustfsBackupService.serviceConfig.ExecStart}
      touch $out
    '';

    # r[verify onix.rustfs_cluster.validation]
    rustfs-topology = pkgs.runCommand "rustfs-topology" { } ''
      ${lib.optionalString (rustfsTopologyPositiveErrors != [ ]) ''
        echo "Valid RustFS topologies produced unexpected errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" rustfsTopologyPositiveErrors)}
        exit 1
      ''}
      ${lib.optionalString (rustfsTopologyMissingNegativeCases != [ ]) ''
        echo "Invalid RustFS topologies did not report expected errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" rustfsTopologyMissingNegativeCases)}
        echo "Actual errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" rustfsTopologyNegativeErrors)}
        exit 1
      ''}
      ${lib.optionalString (rustfsMissingNetlinkMachines != [ ]) ''
        echo "RustFS cannot enumerate local interfaces without AF_NETLINK:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" rustfsMissingNetlinkMachines)}
        exit 1
      ''}
      touch $out
    '';

    # r[verify onix.rustfs_build_caches.storage]
    # r[verify onix.rustfs_build_caches.verification]
    rustfs-bucket-policy = pkgs.runCommand "rustfs-bucket-policy" { } ''
      ${lib.optionalString (rustfsBucketPolicyTests.positiveErrors != [ ]) ''
        echo "Valid RustFS bucket policy settings produced errors"
        exit 1
      ''}
      ${lib.optionalString (rustfsBucketPolicyTests.negativeFailures != [ ]) ''
        echo "Invalid RustFS bucket policy settings were accepted"
        exit 1
      ''}
      ${lib.optionalString (!rustfsBucketPolicyTests.objectResourceIsScoped) ''
        echo "RustFS object policy escaped its bucket"
        exit 1
      ''}
      ${lib.optionalString (!rustfsBucketPolicyTests.objectActionsAreExplicit) ''
        echo "RustFS object policy is missing actions or contains a wildcard"
        exit 1
      ''}
      touch $out
    '';

    # r[verify onix.celld_rustfs.package]
    celld-package = pkgs.runCommand "celld-package" { } ''
      actual="$(${lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.celld} --version)"
      test "$actual" = "celld 0.3.0"
      touch $out
    '';

    # r[verify onix.celld_rustfs.validation]
    celld-settings = pkgs.runCommand "celld-settings" { } ''
      ${lib.optionalString (celldPositiveErrors != [ ]) ''
        echo "Valid Celld settings produced unexpected type errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" celldPositiveErrors)}
        exit 1
      ''}
      ${lib.optionalString (missingCelldNegativeFields != [ ]) ''
        echo "Invalid Celld settings did not report expected fields:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" missingCelldNegativeFields)}
        exit 1
      ''}
      ${lib.optionalString (celldSettingsPositiveErrors != [ ]) ''
        echo "Valid Celld settings produced semantic errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" celldSettingsPositiveErrors)}
        exit 1
      ''}
      ${lib.optionalString (celldSettingsMissingNegativeCases != [ ]) ''
        echo "Invalid Celld settings did not report expected semantic errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" celldSettingsMissingNegativeCases)}
        echo "Actual errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" celldSettingsNegativeErrors)}
        exit 1
      ''}
      touch $out
    '';

    # r[verify onix.celld_rustfs.composition]
    # r[verify onix.celld_rustfs.security]
    # r[verify onix.site_celld_fleet.composition]
    # r[verify onix.site_celld_fleet.credentials]
    # r[verify onix.site_celld_fleet.validation]
    celld-generated = pkgs.runCommand "celld-generated" { } ''
      ${lib.optionalString (builtins.length celldProvisionerMachines != 1) ''
        echo "Celld requires exactly one storage provisioner; found:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" celldProvisionerMachines)}
        exit 1
      ''}
      ${lib.optionalString (celldMissingServices != [ ]) ''
        echo "Celld service is missing from fleet machines:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" celldMissingServices)}
        exit 1
      ''}
      ${lib.optionalString (celldStorageEndpointMismatches != [ ]) ''
        echo "Celld nodes are not aligned with local RustFS endpoints:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" celldStorageEndpointMismatches)}
        exit 1
      ''}
      ${lib.optionalString (celldTailnetFirewallMismatches != [ ]) ''
        echo "Celld firewall ports are not Tailnet-only on:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" celldTailnetFirewallMismatches)}
        exit 1
      ''}
      ${lib.optionalString (!celldDesktopClockProviderValid) ''
        echo "Celld requires Chrony on the NetworkManager-managed desktop"
        exit 1
      ''}
      ${lib.optionalString (!siteCelldPortsAvoidEphemeralRange) ''
        echo "Site Celld listener ports overlap the default Linux ephemeral range"
        exit 1
      ''}
      ${lib.optionalString (siteCelldProvisionerMachines != [ "aspen3" ]) ''
        echo "Site Celld requires aspen3 as its only storage provisioner; found:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" siteCelldProvisionerMachines)}
        exit 1
      ''}
      ${lib.optionalString (siteCelldMissingServices != [ ]) ''
        echo "Site Celld service is missing from fleet machines:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" siteCelldMissingServices)}
        exit 1
      ''}
      ${lib.optionalString (siteCelldMissingIngressServices != [ ]) ''
        echo "Site Celld compatibility ingress is missing from fleet machines:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" siteCelldMissingIngressServices)}
        exit 1
      ''}
      ${lib.optionalString (siteCelldBackendListenerMismatches != [ ]) ''
        echo "Site Celld backend listeners are not isolated behind ingress:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" siteCelldBackendListenerMismatches)}
        exit 1
      ''}
      ${lib.optionalString (siteCelldStorageEndpointMismatches != [ ]) ''
        echo "Site Celld nodes are not aligned with local RustFS endpoints:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" siteCelldStorageEndpointMismatches)}
        exit 1
      ''}
      ${lib.optionalString (siteCelldBucketMismatches != [ ]) ''
        echo "Site Celld nodes do not use the dedicated bucket:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" siteCelldBucketMismatches)}
        exit 1
      ''}
      ${lib.optionalString (siteCelldIsolationMismatches != [ ]) ''
        echo "Site and lab Celld runtime resources overlap on:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" siteCelldIsolationMismatches)}
        exit 1
      ''}
      ${lib.optionalString (siteCelldTailnetFirewallMismatches != [ ]) ''
        echo "Site Celld firewall ports are not Tailnet-only on:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" siteCelldTailnetFirewallMismatches)}
        exit 1
      ''}
      ${lib.optionalString (!siteCelldPublisherCredentialValid) ''
        echo "Site Celld publisher credential ownership is unsafe"
        exit 1
      ''}
      ${lib.optionalString (!celldLabPublisherCredentialAbsent) ''
        echo "Celld lab unexpectedly exposes a publisher credential"
        exit 1
      ''}
      touch $out
    '';

    # r[verify onix.bookshelf.package]
    bookshelf-package = pkgs.runCommand "bookshelf-package" { } ''
      test -x ${lib.escapeShellArg "${self.packages.${pkgs.stdenv.hostPlatform.system}.bookshelf}/bin/bookshelf-server"}
      test -x ${lib.escapeShellArg "${self.packages.${pkgs.stdenv.hostPlatform.system}.bookshelf}/bin/bookshelf-sync"}
      test -f ${lib.escapeShellArg "${self.packages.${pkgs.stdenv.hostPlatform.system}.bookshelf}/share/doc/bookshelf/LICENSE"}
      touch $out
    '';

    # r[verify onix.bookshelf.verification]
    bookshelf-settings = pkgs.runCommand "bookshelf-settings" { } ''
      ${lib.optionalString (bookshelfPositiveErrors != [ ]) ''
        echo "Valid Bookshelf settings produced unexpected type errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" bookshelfPositiveErrors)}
        exit 1
      ''}
      ${lib.optionalString (missingBookshelfNegativeFields != [ ]) ''
        echo "Invalid Bookshelf settings did not report expected fields:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" missingBookshelfNegativeFields)}
        exit 1
      ''}
      ${lib.optionalString (bookshelfSettingsPositiveErrors != [ ]) ''
        echo "Valid Bookshelf settings produced semantic errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" bookshelfSettingsPositiveErrors)}
        exit 1
      ''}
      ${lib.optionalString (bookshelfSettingsMissingNegativeCases != [ ]) ''
        echo "Invalid Bookshelf settings did not report expected semantic errors:"
        printf '%s\n' ${lib.escapeShellArg (lib.concatStringsSep "\n" bookshelfSettingsMissingNegativeCases)}
        echo "Actual errors:"
        printf '%s\n' ${lib.escapeShellArg (builtins.toJSON bookshelfSettingsNegativeErrors)}
        exit 1
      ''}
      touch $out
    '';

    # r[verify onix.bookshelf.storage]
    # r[verify onix.bookshelf.network]
    # r[verify onix.bookshelf.runtime]
    bookshelf-generated = pkgs.runCommand "bookshelf-generated" { } ''
      ${lib.optionalString (!bookshelfEnvironmentValid) ''
        echo "Bookshelf does not use the reviewed filesystem and Tailnet listener environment"
        exit 1
      ''}
      ${lib.optionalString (!bookshelfSandboxValid) ''
        echo "Bookshelf lost its dedicated account or strict writable-path sandbox"
        exit 1
      ''}
      ${lib.optionalString (!bookshelfTailnetFirewallValid) ''
        echo "Bookshelf port is not restricted to tailscale0"
        exit 1
      ''}
      ${lib.optionalString (!bookshelfPrivateDirectoriesValid) ''
        echo "Bookshelf private datapool directories lost their owner or mode"
        exit 1
      ''}
      ${lib.optionalString (!bookshelfPublishServicePresent) ''
        echo "Bookshelf operator publishing service is missing"
        exit 1
      ''}
      ${lib.optionalString (!bookshelfImportToolPresent) ''
        echo "Bookshelf operator import command is missing or duplicated"
        exit 1
      ''}
      ${lib.optionalString bookshelfImportToolPresent ''
        if ${lib.getExe (builtins.head bookshelfImportTools)} >/dev/null 2>&1; then
          echo "Bookshelf import command accepted missing input"
          exit 1
        fi
      ''}
      touch $out
    '';

    # r[verify onix.rustfs_build_caches.kache]
    kache-package =
      pkgs.runCommand "kache-package"
        { nativeBuildInputs = [ self.packages.${pkgs.stdenv.hostPlatform.system}.kache ]; }
        ''
          actual="$(kache --version)"
          if [ "$actual" != "kache 0.16.0" ]; then
            echo "Unexpected Kache version: $actual"
            exit 1
          fi
          if kache unsupported-command >/dev/null 2>&1; then
            echo "Kache accepted an unsupported command"
            exit 1
          fi
          touch $out
        '';

    # r[verify onix.rustfs_build_caches.verification]
    kache-rustfs-settings = pkgs.runCommand "kache-rustfs-settings" { } ''
      ${lib.optionalString (kacheRustfsPositiveErrors != [ ]) ''
        echo "Valid Kache RustFS settings produced type errors"
        exit 1
      ''}
      ${lib.optionalString (missingKacheRustfsNegativeFields != [ ]) ''
        echo "Invalid Kache RustFS settings did not report expected fields"
        exit 1
      ''}
      ${lib.optionalString (kacheRustfsSemanticPositiveErrors != [ ]) ''
        echo "Valid Kache RustFS settings produced semantic errors"
        exit 1
      ''}
      ${lib.optionalString (kacheRustfsMissingNegativeCases != [ ]) ''
        echo "Invalid Kache RustFS settings did not report expected semantic errors"
        exit 1
      ''}
      touch $out
    '';

    # r[verify onix.rustfs_build_caches.verification]
    niks3-settings = pkgs.runCommand "niks3-settings" { } ''
      ${lib.optionalString (niks3PositiveErrors != [ ]) ''
        echo "Valid niks3 settings produced type errors"
        exit 1
      ''}
      ${lib.optionalString (missingNiks3NegativeFields != [ ]) ''
        echo "Invalid niks3 settings did not report expected fields"
        exit 1
      ''}
      ${lib.optionalString (niks3SemanticPositiveErrors != [ ]) ''
        echo "Valid niks3 settings produced semantic errors"
        exit 1
      ''}
      ${lib.optionalString (niks3MissingNegativeCases != [ ]) ''
        echo "Invalid niks3 settings did not report expected semantic errors"
        exit 1
      ''}
      touch $out
    '';

    # r[verify onix.rustfs_build_caches.kache]
    kache-rustfs-generated = pkgs.runCommand "kache-rustfs-generated" { } ''
      ${lib.optionalString (!kacheRustfsGeneratedValid) ''
        echo "Kache RustFS runtime, credentials, provisioner, or sync command drifted"
        exit 1
      ''}
      touch $out
    '';

    # r[verify onix.rustfs_build_caches.monitoring]
    storage-monitoring-generated = pkgs.runCommand "storage-monitoring-generated" { } ''
      ${lib.optionalString (niks3QueueMetricMismatches != [ ]) ''
        echo "niks3 queue metrics are missing from fleet nodes"
        exit 1
      ''}
      ${lib.optionalString (!storageMonitoringValid) ''
        echo "storage blackbox probes or alert rules drifted"
        exit 1
      ''}
      touch $out
    '';

    # r[verify onix.rustfs_build_caches.niks3]
    # r[verify onix.rustfs_build_caches.uploaders]
    niks3-generated = pkgs.runCommand "niks3-generated" { } ''
      ${lib.optionalString (builtins.length niks3Provisioners != 1) ''
        echo "niks3 requires exactly one RustFS provisioner"
        exit 1
      ''}
      ${lib.optionalString (niks3UploaderMismatches != [ ]) ''
        echo "niks3 upload, substitution, or signing trust is missing on fleet nodes"
        exit 1
      ''}
      ${lib.optionalString (!niks3FirewallValid) ''
        echo "niks3 port is not restricted to tailscale0"
        exit 1
      ''}
      ${lib.optionalString (!niks3ServerGeneratedValid) ''
        echo "niks3 server package, RustFS backend, read proxy, or service user drifted"
        exit 1
      ''}
      ${lib.optionalString (!niks3CredentialsValid) ''
        echo "niks3 storage or signing credentials lost private ownership"
        exit 1
      ''}
      ${lib.optionalString (!niks3MetadataBackupValid) ''
        echo "niks3 metadata backup authority drifted"
        exit 1
      ''}
      touch $out
    '';
  };
}
