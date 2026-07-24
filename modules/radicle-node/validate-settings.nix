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
  httpsPort = 443;
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
  isSeeded = rid: builtins.elem rid settings.seedRepositories;
  validSeedRepositoryIds = builtins.all isCanonicalRepositoryId settings.seedRepositories;
  uniqueSeedRepositoryIds = lib.unique settings.seedRepositories == settings.seedRepositories;
  validRepositoryIds = builtins.all isCanonicalRepositoryId settings.pinnedRepositories;
  uniqueRepositoryIds = lib.unique settings.pinnedRepositories == settings.pinnedRepositories;
  pinnedRepositoriesAreSeeded = builtins.all isSeeded settings.pinnedRepositories;
  validHttpsGitRepositoryIds = builtins.all isCanonicalRepositoryId settings.httpsGitRepositories;
  uniqueHttpsGitRepositoryIds =
    lib.unique settings.httpsGitRepositories == settings.httpsGitRepositories;
  httpsGitRepositoriesAreSeeded = builtins.all isSeeded settings.httpsGitRepositories;
  validHttpsAdmission =
    if settings.httpsEnabled then
      settings.httpsServerName != null && settings.httpsGitRepositories != [ ]
    else
      settings.httpsGitRepositories == [ ];
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
  (rejectUnless validHttpsName "httpsServerName must be a public DNS name without scheme or .local suffix")
  (rejectUnless validHttpsTransport "httpsTransport must be direct-acme or cloudflare-tunnel")
  (rejectUnless validHttpsOriginAddress "httpsOriginListenAddress must remain loopback-only")
  (rejectUnless validHttpsAdmission "public HTTPS activation requires a server name and non-empty HTTPS Git repository allowlist, and an allowlist requires activation")
  (rejectUnless validHttpsGitRepositoryIds "httpsGitRepositories must contain only canonical public rad:z repository IDs")
  (rejectUnless uniqueHttpsGitRepositoryIds "httpsGitRepositories must not contain duplicate repository IDs")
  (rejectUnless httpsGitRepositoriesAreSeeded "httpsGitRepositories must be a subset of seedRepositories")
  (rejectUnless (
    settings.minimumSignedRefsFeature == requiredSignedRefsFeature
  ) "minimumSignedRefsFeature must remain parent")
  (rejectUnless validRepositoryIds "pinnedRepositories must contain only canonical rad:z repository IDs")
  (rejectUnless uniqueRepositoryIds "pinnedRepositories must not contain duplicate repository IDs")
  (rejectUnless pinnedRepositoriesAreSeeded "pinnedRepositories must be a subset of seedRepositories")
]
