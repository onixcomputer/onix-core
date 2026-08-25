{ lib }:
settings:
let
  millisecondsPerSecond = 1000;
  bucketNameMinimumLength = 3;
  bucketNameMaximumLength = 63;
  accessKeyMinimumLength = 3;
  wildcardAddresses = [
    "0.0.0.0"
    "::"
    "[::]"
  ];
  statePathSegments = lib.splitString "/" settings.stateDir;
  bucketNameLength = builtins.stringLength settings.bucketName;
  accessKeyLength = builtins.stringLength settings.accessKeyId;
  leaseSeconds = builtins.div (
    settings.leaseTtlMilliseconds + millisecondsPerSecond - 1
  ) millisecondsPerSecond;
  listenerAddressIsSafe =
    settings.bindAddress != ""
    && !(builtins.elem settings.bindAddress wildcardAddresses)
    && !lib.hasInfix " " settings.bindAddress
    && !lib.hasInfix "/" settings.bindAddress;
  storageEndpointIsSafe =
    lib.hasPrefix "http://" settings.storageEndpoint
    && !lib.hasInfix "@" settings.storageEndpoint
    && !lib.hasInfix " " settings.storageEndpoint
    && !lib.hasInfix "?" settings.storageEndpoint
    && !lib.hasInfix "#" settings.storageEndpoint;
  bucketNameIsSafe =
    bucketNameLength >= bucketNameMinimumLength
    && bucketNameLength <= bucketNameMaximumLength
    && builtins.match "^[a-z0-9][a-z0-9.-]*[a-z0-9]$" settings.bucketName != null
    && !lib.hasInfix ".." settings.bucketName;
  accessKeyIsSafe =
    accessKeyLength >= accessKeyMinimumLength
    && builtins.match "^[A-Za-z0-9][A-Za-z0-9_-]*$" settings.accessKeyId != null;
in
{
  # r[impl onix.celld_rustfs.validation]
  inherit leaseSeconds;
  bucketUri = "s3://${settings.bucketName}";
  publicListener = "${settings.bindAddress}:${toString settings.publicPort}";
  internalListener = "${settings.bindAddress}:${toString settings.internalPort}";

  assertions = [
    {
      assertion =
        settings.stateDir != ""
        && settings.stateDir != "/"
        && lib.hasPrefix "/" settings.stateDir
        && !(builtins.elem ".." statePathSegments)
        && !lib.hasInfix " " settings.stateDir;
      message = "celld stateDir must be a private absolute path without spaces or parent traversal";
    }
    {
      assertion = listenerAddressIsSafe;
      message = "celld bindAddress must be an explicit non-wildcard address";
    }
    {
      assertion = storageEndpointIsSafe;
      message = "celld storageEndpoint must be a credential-free HTTP URL";
    }
    {
      assertion = settings.publicPort != settings.internalPort;
      message = "celld publicPort and internalPort must be distinct";
    }
    {
      assertion = bucketNameIsSafe;
      message = "celld bucketName must be a valid lowercase S3 bucket name";
    }
    {
      assertion = accessKeyIsSafe;
      message = "celld accessKeyId must contain only safe identifier characters";
    }
    {
      assertion = settings.region != "" && !lib.hasInfix " " settings.region;
      message = "celld region must be a non-empty token";
    }
    {
      assertion = !settings.openFirewall || settings.firewallInterface == "tailscale0";
      message = "celld open firewall ports must be restricted to tailscale0";
    }
    {
      assertion = settings.leaseTtlMilliseconds > 0;
      message = "celld leaseTtlMilliseconds must be positive";
    }
    {
      assertion = settings.restartDelaySeconds >= leaseSeconds;
      message = "celld restartDelaySeconds must be at least one lease lifetime";
    }
    {
      assertion = settings.shutdownDrainMilliseconds > 0;
      message = "celld shutdownDrainMilliseconds must be positive";
    }
    {
      assertion = !settings.provisionStorage || settings.rustfsAdminGenerator != "";
      message = "celld storage provisioning requires a RustFS administrator generator";
    }
  ];
}
