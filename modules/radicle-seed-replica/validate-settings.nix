# r[impl onix.radicle_replica.configuration]
{ lib }:
{
  settings,
  packageVersion,
  actualHost,
}:
let
  minimumNodeVersion = "1.9.1";
  expectedHost = "britton-desktop";
  expectedDeploymentTarget = "root@100.110.43.11";
  expectedFailureDomain = "britton-desktop-workstation";
  primaryFailureDomain = "aspen-primary-site";
  expectedNodeAddress = "100.110.43.11";
  expectedNodePort = 8776;
  expectedNodeInterface = "tailscale0";
  expectedStateDirectory = "/var/lib/radicle";
  expectedStateDataset = "datapool/radicle-seed";
  maximumStateQuotaGiB = 64;
  maximumFingerprintPadding = 2;
  requiredSignedRefsFeature = "parent";
  bootstrapNodeFingerprint = "SHA256:zwNJTV2uBfWYcFXeFJs+eAfatqahgK8KKe+4gdGkOSE";
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
  fingerprintPattern = "SHA256:[A-Za-z0-9+/]+={0,${toString maximumFingerprintPadding}}";

  rejectUnless = condition: message: lib.optional (!condition) message;
  isCanonicalRepositoryId = rid: builtins.match canonicalRepositoryIdPattern rid != null;
  validRepositoryIds = builtins.all isCanonicalRepositoryId settings.seedRepositories;
  uniqueRepositoryIds = lib.unique settings.seedRepositories == settings.seedRepositories;
  validPrivateRepositoryIds = builtins.all isCanonicalRepositoryId settings.privateSeedRepositories;
  uniquePrivateRepositoryIds =
    lib.unique settings.privateSeedRepositories == settings.privateSeedRepositories;
  privateRepositoryClassesAreDisjoint = builtins.all (
    rid: !(builtins.elem rid settings.seedRepositories)
  ) settings.privateSeedRepositories;
  validFingerprint = builtins.match fingerprintPattern settings.expectedNodeFingerprint != null;
in
lib.concatLists [
  (rejectUnless (lib.versionAtLeast packageVersion minimumNodeVersion) "radicle-node package must be version ${minimumNodeVersion} or later")
  (rejectUnless (
    settings.expectedHost == expectedHost && actualHost == expectedHost
  ) "secondary Radicle seed must be evaluated only on britton-desktop")
  (rejectUnless (
    settings.deploymentTarget == expectedDeploymentTarget
  ) "secondary Radicle seed deploymentTarget must remain ${expectedDeploymentTarget}")
  (rejectUnless (
    settings.failureDomain == expectedFailureDomain && settings.failureDomain != primaryFailureDomain
  ) "secondary Radicle seed must remain in the reviewed desktop failure domain")
  (rejectUnless (settings.alias != "") "secondary Radicle seed alias must not be empty")
  (rejectUnless settings.monitoringRequired "secondary Radicle seed monitoring must remain required")
  (rejectUnless (
    settings.nodeListenAddress == expectedNodeAddress
  ) "secondary Radicle seed nodeListenAddress must remain ${expectedNodeAddress}")
  (rejectUnless (
    settings.nodeListenPort == expectedNodePort
  ) "secondary Radicle seed nodeListenPort must remain ${toString expectedNodePort}")
  (rejectUnless (
    settings.nodeFirewallInterface == expectedNodeInterface
  ) "secondary Radicle seed firewall must remain scoped to ${expectedNodeInterface}")
  (rejectUnless (
    settings.externalAddress == "${expectedNodeAddress}:${toString expectedNodePort}"
  ) "secondary Radicle seed externalAddress must match its reviewed listener")
  (rejectUnless validRepositoryIds "secondary Radicle seed repositories must be canonical public rad:z IDs")
  (rejectUnless uniqueRepositoryIds "secondary Radicle seed repositories must not contain duplicates")
  (rejectUnless (settings.seedRepositories == governedRepositories)
    "secondary Radicle seed must admit exactly the governed Bounded Exec, artifact-auth, execution-graph, and Choregraph RIDs in the public set"
  )
  (rejectUnless validPrivateRepositoryIds "secondary Radicle private seed repositories must be canonical rad:z IDs")
  (rejectUnless uniquePrivateRepositoryIds "secondary Radicle private seed repositories must not contain duplicates")
  (rejectUnless (
    settings.privateSeedRepositories == governedPrivateRepositories
  ) "secondary Radicle seed must admit exactly the reviewed private pilot RID")
  (rejectUnless privateRepositoryClassesAreDisjoint "secondary Radicle public and private repository sets must be disjoint")
  (rejectUnless (
    settings.stateDirectory == expectedStateDirectory
  ) "secondary Radicle seed stateDirectory must remain ${expectedStateDirectory}")
  (rejectUnless (
    settings.stateDataset == expectedStateDataset
  ) "secondary Radicle seed stateDataset must remain ${expectedStateDataset}")
  (rejectUnless (settings.stateQuotaGiB > 0 && settings.stateQuotaGiB <= maximumStateQuotaGiB)
    "secondary Radicle seed state quota must be positive and no greater than ${toString maximumStateQuotaGiB} GiB"
  )
  (rejectUnless (
    settings.minimumSignedRefsFeature == requiredSignedRefsFeature
  ) "secondary Radicle seed minimumSignedRefsFeature must remain parent")
  (rejectUnless validFingerprint "secondary Radicle seed expectedNodeFingerprint must be an OpenSSH SHA256 fingerprint")
  (rejectUnless (
    settings.expectedNodeFingerprint != bootstrapNodeFingerprint
  ) "secondary Radicle seed must not reuse the Aspen1 node identity")
]
