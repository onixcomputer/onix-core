# r[impl onix.radicle_node.configuration]
# r[impl onix.radicle_node.validation]
{ lib }:
{
  settings,
  packageVersion,
  actualHost,
}:
let
  minimumNodeVersion = "1.9.1";
  expectedHost = "aspen1";
  expectedDeploymentTarget = "root@aspen1.local";
  expectedNodeFingerprint = "SHA256:zwNJTV2uBfWYcFXeFJs+eAfatqahgK8KKe+4gdGkOSE";
  requiredSignedRefsFeature = "parent";
  expectedBackupTargetHost = "britton-desktop";
  expectedBackupTargetAddress = "100.110.43.11";
  expectedBackupTargetFailureDomain = "britton-desktop-workstation";
  expectedBackupRepositoryPath = "/var/lib/radicle-backup";
  expectedBackupDataset = "datapool/radicle-backup";
  requiredBackupManifestAlgorithm = "blake3";
  minimumBackupQuotaGiB = 128;
  maximumBackupQuotaGiB = 1024;
  minimumDailyRetention = 1;
  maximumDailyRetention = 31;
  minimumWeeklyRetention = 1;
  maximumWeeklyRetention = 8;
  httpsPort = 443;
  boundedExecRepository = "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo";
  artifactAuthRepository = "rad:z4JGYYW7WsesXUq7MXVdx16Fawu2f";
  executionGraphRepository = "rad:z2oYsb9jGTyp68BKYhzpivY1eK58a";
  choregraphRepository = "rad:zL2ncTUeASVYwcoGkEXv9JKgGbAF";
  governedRepositories = [
    boundedExecRepository
    artifactAuthRepository
    executionGraphRepository
    choregraphRepository
  ];
  privatePilotRepository = "rad:z3t9ykR1HfG9UkyKoQQg5ikkzrTxg";
  governedPrivateRepositories = [ privatePilotRepository ];
  canonicalRepositoryIdPattern = "rad:z[1-9A-HJ-NP-Za-km-z]+";

  rejectUnless = condition: message: lib.optional (!condition) message;
  isWildcard =
    address:
    builtins.elem address [
      "0.0.0.0"
      "::"
      "[::]"
    ];
  isLoopback = address: address == "::1" || lib.hasPrefix "127." address;
  isLoopbackHttp = address: address == "::1" || address == "127.0.0.1";
  validExternalAddress =
    settings.externalAddress == null
    || (
      settings.externalAddress != ""
      && lib.hasInfix ":" settings.externalAddress
      && lib.hasSuffix ":${toString settings.nodeListenPort}" settings.externalAddress
      && !(lib.hasPrefix "http://" settings.externalAddress)
      && !(lib.hasPrefix "https://" settings.externalAddress)
    );
  validHttpsName =
    settings.httpsServerName == null
    || (
      settings.httpsServerName != ""
      && !(lib.hasSuffix ".local" settings.httpsServerName)
      && !(lib.hasPrefix "http://" settings.httpsServerName)
      && !(lib.hasPrefix "https://" settings.httpsServerName)
    );
  validHttpsTransport = builtins.elem settings.httpsTransport [
    "direct-acme"
    "cloudflare-tunnel"
  ];
  validHttpsOriginAddress = isLoopbackHttp settings.httpsOriginListenAddress;
  httpsOriginPortIsDistinct =
    settings.httpsOriginListenPort != settings.nodeListenPort
    && settings.httpsOriginListenPort != settings.httpListenPort
    && settings.httpsOriginListenPort != httpsPort;
  isCanonicalRepositoryId = rid: builtins.match canonicalRepositoryIdPattern rid != null;
  isPubliclySeeded = rid: builtins.elem rid settings.seedRepositories;
  validSeedRepositoryIds = builtins.all isCanonicalRepositoryId settings.seedRepositories;
  uniqueSeedRepositoryIds = lib.unique settings.seedRepositories == settings.seedRepositories;
  seedRepositoriesAreGoverned = settings.seedRepositories == governedRepositories;
  validPrivateSeedRepositoryIds = builtins.all isCanonicalRepositoryId settings.privateSeedRepositories;
  uniquePrivateSeedRepositoryIds =
    lib.unique settings.privateSeedRepositories == settings.privateSeedRepositories;
  privateSeedRepositoriesAreGoverned =
    settings.privateSeedRepositories == governedPrivateRepositories;
  seedRepositoryClassesAreDisjoint = builtins.all (
    rid: !(builtins.elem rid settings.seedRepositories)
  ) settings.privateSeedRepositories;
  validRepositoryIds = builtins.all isCanonicalRepositoryId settings.pinnedRepositories;
  uniqueRepositoryIds = lib.unique settings.pinnedRepositories == settings.pinnedRepositories;
  pinnedRepositoriesAreSeeded = builtins.all isPubliclySeeded settings.pinnedRepositories;
  validHttpsGitRepositoryIds = builtins.all isCanonicalRepositoryId settings.httpsGitRepositories;
  uniqueHttpsGitRepositoryIds =
    lib.unique settings.httpsGitRepositories == settings.httpsGitRepositories;
  httpsGitRepositoriesAreSeeded = builtins.all isPubliclySeeded settings.httpsGitRepositories;
  httpsGitRepositoriesAreGoverned =
    !settings.httpsEnabled || settings.httpsGitRepositories == governedRepositories;
  validHttpsAdmission =
    if settings.httpsEnabled then
      settings.httpsServerName != null && settings.httpsGitRepositories != [ ]
    else
      settings.httpsGitRepositories == [ ];
  backupFactsPresent =
    settings.backupTargetHost != null
    && settings.backupTargetAddress != null
    && settings.backupTargetFailureDomain != null
    && settings.backupRepositoryPath != null
    && settings.backupDataset != null;
  backupFactsAbsent =
    settings.backupTargetHost == null
    && settings.backupTargetAddress == null
    && settings.backupTargetFailureDomain == null
    && settings.backupRepositoryPath == null
    && settings.backupDataset == null;
  backupTargetIsReviewed =
    settings.backupTargetHost == expectedBackupTargetHost
    && settings.backupTargetAddress == expectedBackupTargetAddress
    && settings.backupTargetFailureDomain == expectedBackupTargetFailureDomain
    && settings.backupRepositoryPath == expectedBackupRepositoryPath
    && settings.backupDataset == expectedBackupDataset;
  backupLeavesSourceFailureDomain =
    settings.backupTargetHost != settings.expectedHost
    && settings.backupTargetFailureDomain != settings.failureDomain;
  validBackupQuota =
    settings.backupDatasetQuotaGiB >= minimumBackupQuotaGiB
    && settings.backupDatasetQuotaGiB <= maximumBackupQuotaGiB;
  validBackupRetention =
    settings.backupRetentionDaily >= minimumDailyRetention
    && settings.backupRetentionDaily <= maximumDailyRetention
    && settings.backupRetentionWeekly >= minimumWeeklyRetention
    && settings.backupRetentionWeekly <= maximumWeeklyRetention;
  validBackupAdmission =
    if settings.backupEnabled then
      backupFactsPresent
      && backupTargetIsReviewed
      && backupLeavesSourceFailureDomain
      && validBackupQuota
      && validBackupRetention
      && settings.backupManifestAlgorithm == requiredBackupManifestAlgorithm
    else
      backupFactsAbsent;
in
lib.concatLists [
  (rejectUnless (lib.versionAtLeast packageVersion minimumNodeVersion) "radicle-node package must be version ${minimumNodeVersion} or later")
  (rejectUnless (
    settings.expectedHost == expectedHost
  ) "expectedHost must remain ${expectedHost} for the bootstrap change")
  (rejectUnless (
    actualHost == settings.expectedHost
  ) "Radicle bootstrap service must be evaluated only on the selected host")
  (rejectUnless (
    settings.deploymentTarget == expectedDeploymentTarget
  ) "deploymentTarget must remain ${expectedDeploymentTarget}")
  (rejectUnless (
    settings.expectedNodeFingerprint == expectedNodeFingerprint
  ) "expectedNodeFingerprint must preserve the recovered Aspen1 node identity")
  (rejectUnless (settings.alias != "") "alias must not be empty")
  (rejectUnless (settings.failureDomain != "") "failureDomain must not be empty")
  (rejectUnless settings.monitoringRequired "monitoringRequired must remain enabled")
  (rejectUnless (
    !(isWildcard settings.nodeListenAddress)
  ) "nodeListenAddress must not be a wildcard address")
  (rejectUnless (
    !(isLoopback settings.nodeListenAddress)
  ) "nodeListenAddress must be reachable by an admitted peer and must not be loopback")
  (rejectUnless (
    settings.nodeFirewallInterface != "" && settings.nodeFirewallInterface != "lo"
  ) "nodeFirewallInterface must name one non-loopback interface")
  (rejectUnless (
    settings.nodeListenPort != settings.httpListenPort
  ) "nodeListenPort and httpListenPort must be distinct")
  (rejectUnless httpsOriginPortIsDistinct "httpsOriginListenPort, HTTPS, native peer, and HTTP gateway ports must be distinct")
  (rejectUnless (
    !settings.httpsEnabled
    || (settings.nodeListenPort != httpsPort && settings.httpListenPort != httpsPort)
  ) "HTTPS, native peer, and HTTP gateway ports must be distinct")
  (rejectUnless validExternalAddress "externalAddress must be null or a host:nodeListenPort Radicle address without a URL scheme")
  (rejectUnless (isLoopbackHttp settings.httpListenAddress) "httpListenAddress must remain loopback-only")
  (rejectUnless (
    settings.httpdEnabled || !settings.httpsEnabled
  ) "httpsEnabled requires the read-only HTTP gateway")
  (rejectUnless validSeedRepositoryIds "seedRepositories must contain only canonical public rad:z repository IDs")
  (rejectUnless uniqueSeedRepositoryIds "seedRepositories must not contain duplicate repository IDs")
  (rejectUnless seedRepositoriesAreGoverned "seedRepositories must contain exactly the governed Bounded Exec, artifact-auth, execution-graph, and Choregraph RIDs in the public set")
  (rejectUnless validPrivateSeedRepositoryIds "privateSeedRepositories must contain only canonical rad:z repository IDs")
  (rejectUnless uniquePrivateSeedRepositoryIds "privateSeedRepositories must not contain duplicate repository IDs")
  (rejectUnless privateSeedRepositoriesAreGoverned "privateSeedRepositories must contain exactly the reviewed private pilot RID")
  (rejectUnless seedRepositoryClassesAreDisjoint "public and private seed repository sets must be disjoint")
  (rejectUnless validHttpsName "httpsServerName must be a public DNS name without scheme or .local suffix")
  (rejectUnless validHttpsTransport "httpsTransport must be direct-acme or cloudflare-tunnel")
  (rejectUnless validHttpsOriginAddress "httpsOriginListenAddress must remain loopback-only")
  (rejectUnless validHttpsAdmission "public HTTPS activation requires a server name and non-empty HTTPS Git repository allowlist, and an allowlist requires activation")
  (rejectUnless validHttpsGitRepositoryIds "httpsGitRepositories must contain only canonical public rad:z repository IDs")
  (rejectUnless uniqueHttpsGitRepositoryIds "httpsGitRepositories must not contain duplicate repository IDs")
  (rejectUnless httpsGitRepositoriesAreSeeded "httpsGitRepositories must be a subset of seedRepositories")
  (rejectUnless httpsGitRepositoriesAreGoverned "enabled HTTPS Git must expose exactly the governed Bounded Exec, artifact-auth, execution-graph, and Choregraph RIDs")
  (rejectUnless (!settings.backupEnabled || backupFactsPresent)
    "enabled backup requires complete target host, address, failure-domain, repository, and dataset facts"
  )
  (rejectUnless (
    !settings.backupEnabled || backupTargetIsReviewed
  ) "backup target must remain the reviewed britton-desktop dataset and address")
  (rejectUnless (
    !settings.backupEnabled || backupLeavesSourceFailureDomain
  ) "backup target host and failure domain must differ from the Radicle source")
  (rejectUnless validBackupQuota "backupDatasetQuotaGiB must remain between 128 and 1024 GiB")
  (rejectUnless validBackupRetention "backup retention must remain positive and bounded")
  (rejectUnless (
    settings.backupManifestAlgorithm == requiredBackupManifestAlgorithm
  ) "backupManifestAlgorithm must remain blake3")
  (rejectUnless validBackupAdmission "backup activation and complete reviewed target facts must agree")
  (rejectUnless (
    settings.minimumSignedRefsFeature == requiredSignedRefsFeature
  ) "minimumSignedRefsFeature must remain parent")
  (rejectUnless validRepositoryIds "pinnedRepositories must contain only canonical rad:z repository IDs")
  (rejectUnless uniqueRepositoryIds "pinnedRepositories must not contain duplicate repository IDs")
  (rejectUnless pinnedRepositoriesAreSeeded "pinnedRepositories must be a subset of seedRepositories")
]
