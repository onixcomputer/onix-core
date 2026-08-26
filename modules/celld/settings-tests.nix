{ lib }:
let
  mkSettings = import ./settings.nix { inherit lib; };
  testPublicPort = 39200;
  testInternalPort = 39201;
  testLeaseTtlMilliseconds = 10000;
  testRestartDelaySeconds = 10;
  testShutdownDrainMilliseconds = 25000;
  testAddress = "100.64.0.1";
  baseSettings = {
    runtimeName = "celld";
    stateDir = "/var/lib/celld-lab";
    bindAddress = testAddress;
    storageEndpoint = "http://${testAddress}:39000";
    bucketName = "celld-lab";
    region = "us-east-1";
    accessKeyId = "celld-lab";
    publisherUser = null;
    publicPort = testPublicPort;
    internalPort = testInternalPort;
    stripTrailingSlashProxy = false;
    backendPort = 39202;
    openFirewall = true;
    firewallInterface = "tailscale0";
    provisionStorage = true;
    rustfsAdminGenerator = "rustfs-rustfs-cluster";
    deployCounter = true;
    leaseTtlMilliseconds = testLeaseTtlMilliseconds;
    restartDelaySeconds = testRestartDelaySeconds;
    shutdownDrainMilliseconds = testShutdownDrainMilliseconds;
  };
  errorsFor =
    settings:
    builtins.map (entry: entry.message) (
      builtins.filter (entry: !entry.assertion) (mkSettings settings).assertions
    );
  negativeCases = [
    {
      name = "unsafe-runtime-name";
      expected = "runtimeName";
      settings = baseSettings // {
        runtimeName = "celld/site";
      };
    }
    {
      name = "unsafe-publisher-user";
      expected = "publisherUser";
      settings = baseSettings // {
        publisherUser = "bad user";
      };
    }
    {
      name = "wildcard-listener";
      expected = "non-wildcard";
      settings = baseSettings // {
        bindAddress = "0.0.0.0";
      };
    }
    {
      name = "shared-listener-port";
      expected = "must be distinct";
      settings = baseSettings // {
        internalPort = testPublicPort;
      };
    }
    {
      name = "shared-proxy-backend-port";
      expected = "backendPort";
      settings = baseSettings // {
        stripTrailingSlashProxy = true;
        backendPort = testPublicPort;
      };
    }
    {
      name = "unsafe-bucket";
      expected = "valid lowercase S3 bucket";
      settings = baseSettings // {
        bucketName = "Bad_Bucket";
      };
    }
    {
      name = "root-state-directory";
      expected = "private absolute path";
      settings = baseSettings // {
        stateDir = "/";
      };
    }
    {
      name = "credential-bearing-endpoint";
      expected = "credential-free";
      settings = baseSettings // {
        storageEndpoint = "http://user@${testAddress}:39000";
      };
    }
    {
      name = "global-firewall";
      expected = "restricted to tailscale0";
      settings = baseSettings // {
        firewallInterface = null;
      };
    }
    {
      name = "short-restart-delay";
      expected = "one lease lifetime";
      settings = baseSettings // {
        restartDelaySeconds = testRestartDelaySeconds - 1;
      };
    }
    {
      name = "missing-admin-generator";
      expected = "administrator generator";
      settings = baseSettings // {
        rustfsAdminGenerator = "";
      };
    }
  ];
  negativeResults = builtins.map (
    case:
    let
      errors = errorsFor case.settings;
    in
    case
    // {
      inherit errors;
      found = lib.any (error: lib.hasInfix case.expected error) errors;
    }
  ) negativeCases;
in
{
  # r[verify onix.celld_rustfs.validation]
  positiveErrors = errorsFor baseSettings;
  missingNegativeCases = builtins.map (case: case.name) (
    builtins.filter (case: !case.found) negativeResults
  );
  negativeErrors = lib.concatMap (case: case.errors) negativeResults;
}
