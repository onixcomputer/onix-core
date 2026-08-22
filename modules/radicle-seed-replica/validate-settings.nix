# r[impl onix.radicle_replica.configuration]
# r[impl onix.radicle_replica.identity_distinct]
# r[impl onix.radicle_source_admission.validation]
{ lib }:
{
  settings,
  packageVersion,
  actualHost,
  reviewedHosts ? import ./reviewed-hosts.nix,
}:
let
  minimumNodeVersion = "1.9.1";
  primaryFailureDomain = "aspen-primary-site";
  expectedNodePort = 8776;
  expectedNodeInterface = "tailscale0";
  expectedStateDirectory = "/var/lib/radicle";
  maximumStateQuotaGiB = 64;
  maximumFingerprintPadding = 2;
  requiredSignedRefsFeature = "parent";
  bootstrapNodeFingerprint = "SHA256:zwNJTV2uBfWYcFXeFJs+eAfatqahgK8KKe+4gdGkOSE";
  boundedExecRepository = "rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo";
  artifactAuthRepository = "rad:z4JGYYW7WsesXUq7MXVdx16Fawu2f";
  executionGraphRepository = "rad:z2oYsb9jGTyp68BKYhzpivY1eK58a";
  choregraphRepository = "rad:zL2ncTUeASVYwcoGkEXv9JKgGbAF";
  durableFilePublicationRepository = "rad:z3tAR4For7qw8ZirkJzoDw1VNDDLM";
  koiterminalRepository = "rad:z2JQ8ihZZ6wraULQPzFWMh25B29rZ";
  governedRepositories = [
    boundedExecRepository
    artifactAuthRepository
    executionGraphRepository
    choregraphRepository
    durableFilePublicationRepository
    koiterminalRepository
  ];
  privatePilotRepository = "rad:z3t9ykR1HfG9UkyKoQQg5ikkzrTxg";
  privateSeaglassRepository = "rad:z3xXXCQXCTquvAawh41YYs8yC8xmk";
  privateHardenedWasmtimeRepository = "rad:z3hRCegTsS8jpJVgxYfb9psEzxHpG";
  governedPrivateRepositories = [
    privatePilotRepository
    privateSeaglassRepository
    privateHardenedWasmtimeRepository
  ];
  canonicalRepositoryIdPattern = "rad:z[1-9A-HJ-NP-Za-km-z]+";
  fingerprintPattern = "SHA256:[A-Za-z0-9+/]+={0,${toString maximumFingerprintPadding}}";

  rejectUnless = condition: message: lib.optional (!condition) message;
  isCanonicalRepositoryId = rid: builtins.match canonicalRepositoryIdPattern rid != null;
  isValidFingerprint = fingerprint: builtins.match fingerprintPattern fingerprint != null;
  validRepositoryIds = builtins.all isCanonicalRepositoryId settings.seedRepositories;
  uniqueRepositoryIds = lib.unique settings.seedRepositories == settings.seedRepositories;
  validPrivateRepositoryIds = builtins.all isCanonicalRepositoryId settings.privateSeedRepositories;
  uniquePrivateRepositoryIds =
    lib.unique settings.privateSeedRepositories == settings.privateSeedRepositories;
  privateRepositoryClassesAreDisjoint = builtins.all (
    rid: !(builtins.elem rid settings.seedRepositories)
  ) settings.privateSeedRepositories;

  reviewedHost = reviewedHosts.${settings.expectedHost} or null;
  hostIsReviewed = reviewedHost != null;
  hostFactMatches = field: hostIsReviewed && settings.${field} == reviewedHost.${field};
  addressMatches = hostIsReviewed && settings.nodeListenAddress == reviewedHost.nodeAddress;
  externalAddressMatches =
    hostIsReviewed
    && settings.externalAddress == "${reviewedHost.nodeAddress}:${toString expectedNodePort}";
  datasetMatches = hostIsReviewed && settings.stateDataset == reviewedHost.stateDataset;
  fingerprintMatches =
    hostIsReviewed && settings.expectedNodeFingerprint == reviewedHost.nodeFingerprint;

  reviewedFingerprints = map (host: reviewedHosts.${host}.nodeFingerprint) (
    builtins.attrNames reviewedHosts
  );
  reviewedFingerprintsAreValid = builtins.all isValidFingerprint reviewedFingerprints;
  reviewedFingerprintsAreUnique = lib.unique reviewedFingerprints == reviewedFingerprints;
  reviewedFingerprintsExcludeBootstrap =
    !(builtins.elem bootstrapNodeFingerprint reviewedFingerprints);
in
lib.concatLists [
  (rejectUnless (lib.versionAtLeast packageVersion minimumNodeVersion) "radicle-node package must be version ${minimumNodeVersion} or later")
  (rejectUnless (
    hostIsReviewed && settings.expectedHost == actualHost
  ) "Radicle replica must be evaluated only on a reviewed host with matching expectedHost")
  (rejectUnless (hostFactMatches "deploymentTarget") "Radicle replica deploymentTarget must match the reviewed host")
  (rejectUnless (
    hostFactMatches "failureDomain" && settings.failureDomain != primaryFailureDomain
  ) "Radicle replica failureDomain must match the reviewed host and differ from Aspen1")
  (rejectUnless (settings.alias != "") "Radicle replica alias must not be empty")
  (rejectUnless settings.monitoringRequired "Radicle replica monitoring must remain required")
  (rejectUnless addressMatches "Radicle replica nodeListenAddress must match the reviewed host")
  (rejectUnless (
    settings.nodeListenPort == expectedNodePort
  ) "Radicle replica nodeListenPort must remain ${toString expectedNodePort}")
  (rejectUnless (
    settings.nodeFirewallInterface == expectedNodeInterface
  ) "Radicle replica firewall must remain scoped to ${expectedNodeInterface}")
  (rejectUnless externalAddressMatches "Radicle replica externalAddress must match its reviewed listener")
  (rejectUnless validRepositoryIds "Radicle replica repositories must be canonical public rad:z IDs")
  (rejectUnless uniqueRepositoryIds "Radicle replica repositories must not contain duplicates")
  (rejectUnless (settings.seedRepositories == governedRepositories)
    "Radicle replica must admit exactly the governed Bounded Exec, artifact-auth, execution-graph, and Choregraph RIDs in the public set; it must also admit the durable-file-publication and koiTerminal fork RIDs"
  )
  (rejectUnless validPrivateRepositoryIds "Radicle private seed repositories must be canonical rad:z IDs")
  (rejectUnless uniquePrivateRepositoryIds "Radicle private seed repositories must not contain duplicates")
  (rejectUnless (
    settings.privateSeedRepositories == governedPrivateRepositories
  ) "Radicle replica must admit exactly the reviewed private repository set")
  (rejectUnless privateRepositoryClassesAreDisjoint "Radicle public and private repository sets must be disjoint")
  (rejectUnless (
    settings.stateDirectory == expectedStateDirectory
  ) "Radicle replica stateDirectory must remain ${expectedStateDirectory}")
  (rejectUnless datasetMatches "Radicle replica stateDataset must match the reviewed host")
  (rejectUnless (settings.stateQuotaGiB > 0 && settings.stateQuotaGiB <= maximumStateQuotaGiB)
    "Radicle replica state quota must be positive and no greater than ${toString maximumStateQuotaGiB} GiB"
  )
  (rejectUnless (
    settings.minimumSignedRefsFeature == requiredSignedRefsFeature
  ) "Radicle replica minimumSignedRefsFeature must remain parent")
  (rejectUnless (isValidFingerprint settings.expectedNodeFingerprint) "Radicle replica expectedNodeFingerprint must be an OpenSSH SHA256 fingerprint")
  (rejectUnless fingerprintMatches "Radicle replica expectedNodeFingerprint must match the reviewed host")
  (rejectUnless (
    settings.expectedNodeFingerprint != bootstrapNodeFingerprint
  ) "Radicle replicas must not reuse the Aspen1 node identity")
  (rejectUnless reviewedFingerprintsAreValid "Reviewed Radicle replica fingerprints must use the OpenSSH SHA256 form")
  (rejectUnless reviewedFingerprintsAreUnique "Reviewed Radicle seed fingerprints must remain unique")
  (rejectUnless reviewedFingerprintsExcludeBootstrap "Radicle replicas must not reuse the Aspen1 node identity")
]
