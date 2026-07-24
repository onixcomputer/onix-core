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
  requiredSignedRefsFeature = "parent";
  credentialNamespace = "onix.radicle.";
  httpsPort = 443;

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
  publicKeyParts = lib.splitString " " settings.publicKey;
  validPublicKey =
    builtins.length publicKeyParts == 2
    && builtins.elemAt publicKeyParts 0 == "ssh-ed25519"
    && lib.hasPrefix "AAAA" (builtins.elemAt publicKeyParts 1)
    && !(lib.hasInfix "\n" settings.publicKey)
    && !(lib.hasInfix "\r" settings.publicKey);
  validCredentialName =
    lib.hasPrefix credentialNamespace settings.privateKeyCredential
    && !(lib.hasInfix "/" settings.privateKeyCredential)
    && !(lib.hasInfix ":" settings.privateKeyCredential);
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
  validRepositoryIds = builtins.all (rid: lib.hasPrefix "rad:" rid) settings.pinnedRepositories;
  uniqueRepositoryIds = lib.unique settings.pinnedRepositories == settings.pinnedRepositories;
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
  (rejectUnless (settings.alias != "") "alias must not be empty")
  (rejectUnless (settings.failureDomain != "") "failureDomain must not be empty")
  (rejectUnless validPublicKey "publicKey must be one uncommented ssh-ed25519 public key")
  (rejectUnless validCredentialName "privateKeyCredential must use the onix.radicle namespace without path or mapping syntax")
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
  (rejectUnless (
    settings.httpsServerName == null
    || (settings.nodeListenPort != httpsPort && settings.httpListenPort != httpsPort)
  ) "HTTPS, native peer, and HTTP gateway ports must be distinct")
  (rejectUnless validExternalAddress "externalAddress must be null or a host:nodeListenPort Radicle address without a URL scheme")
  (rejectUnless (isLoopbackHttp settings.httpListenAddress) "httpListenAddress must remain loopback-only")
  (rejectUnless (
    settings.httpdEnabled || settings.httpsServerName == null
  ) "httpsServerName requires the read-only HTTP gateway")
  (rejectUnless validHttpsName "httpsServerName must be a public DNS name without scheme or .local suffix")
  (rejectUnless (
    settings.minimumSignedRefsFeature == requiredSignedRefsFeature
  ) "minimumSignedRefsFeature must remain parent")
  (rejectUnless validRepositoryIds "pinnedRepositories must contain only rad: repository IDs")
  (rejectUnless uniqueRepositoryIds "pinnedRepositories must not contain duplicate repository IDs")
]
