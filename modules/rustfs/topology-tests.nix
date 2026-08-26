{ lib }:
let
  mkTopology = import ./topology.nix { inherit lib; };
  testApiPort = 39000;
  testConsolePort = 39001;
  wrongApiPort = 39002;
  topologyWaitTimeoutSeconds = 120;
  defaultResourceWeight = 100;
  protectedOomScoreAdjust = -1000;
  invalidOomScoreAdjust = 1001;
  localAddress = "100.64.0.1";
  peerAddressA = "100.64.0.2";
  peerAddressB = "100.64.0.3";
  peerAddressC = "100.64.0.4";
  localDataDir = "/srv/rustfs-cluster";
  peerDataDirA = "/srv/rustfs-cluster-a";
  peerDataDirB = "/srv/rustfs-cluster-b";
  localEndpoint = "http://${localAddress}:${toString testApiPort}${localDataDir}";
  peerEndpointA = "http://${peerAddressA}:${toString testApiPort}${peerDataDirA}";
  peerEndpointB = "http://${peerAddressB}:${toString testApiPort}${peerDataDirB}";
  validEndpoints = [
    localEndpoint
    peerEndpointA
    peerEndpointB
  ];
  baseSettings = {
    mode = "single";
    serviceName = "rustfs";
    dataDir = localDataDir;
    bindAddress = "0.0.0.0";
    apiPort = testApiPort;
    consolePort = testConsolePort;
    enableConsole = true;
    clusterEndpoints = [ ];
    topologyWaitMode = "bounded";
    cpuWeight = defaultResourceWeight;
    ioWeight = defaultResourceWeight;
    nice = 0;
    oomScoreAdjust = protectedOomScoreAdjust;
    inherit topologyWaitTimeoutSeconds;
  };
  validDistributedSettings = baseSettings // {
    mode = "distributed";
    bindAddress = localAddress;
    clusterEndpoints = validEndpoints;
  };
  errorsFor =
    settings:
    builtins.map (entry: entry.message) (
      builtins.filter (entry: !entry.assertion) (mkTopology settings).assertions
    );
  negativeCases = [
    {
      name = "unsafe-service-name";
      expected = "serviceName";
      settings = baseSettings // {
        serviceName = "rustfs cache";
      };
    }
    {
      name = "zero-cpu-weight";
      expected = "cpuWeight";
      settings = baseSettings // {
        cpuWeight = 0;
      };
    }
    {
      name = "invalid-oom-score";
      expected = "oomScoreAdjust";
      settings = baseSettings // {
        oomScoreAdjust = invalidOomScoreAdjust;
      };
    }
    {
      name = "too-few-endpoints";
      expected = "at least";
      settings = validDistributedSettings // {
        clusterEndpoints = [
          localEndpoint
          peerEndpointA
        ];
      };
    }
    {
      name = "duplicate-endpoint";
      expected = "unique";
      settings = validDistributedSettings // {
        clusterEndpoints = [
          localEndpoint
          peerEndpointA
          peerEndpointA
        ];
      };
    }
    {
      name = "wildcard-bind";
      expected = "wildcard";
      settings = validDistributedSettings // {
        bindAddress = "0.0.0.0";
        clusterEndpoints = [
          "http://0.0.0.0:${toString testApiPort}${localDataDir}"
          peerEndpointA
          peerEndpointB
        ];
      };
    }
    {
      name = "missing-local-endpoint";
      expected = "exact local endpoint";
      settings = validDistributedSettings // {
        clusterEndpoints = [
          "http://${peerAddressC}:${toString testApiPort}/srv/rustfs-cluster-c"
          peerEndpointA
          peerEndpointB
        ];
      };
    }
    {
      name = "wrong-api-port";
      expected = "configured apiPort";
      settings = validDistributedSettings // {
        clusterEndpoints = [
          localEndpoint
          "http://${peerAddressA}:${toString wrongApiPort}${peerDataDirA}"
          peerEndpointB
        ];
      };
    }
    {
      name = "root-endpoint-path";
      expected = "absolute paths";
      settings = validDistributedSettings // {
        clusterEndpoints = [
          localEndpoint
          "http://${peerAddressA}:${toString testApiPort}/"
          peerEndpointB
        ];
      };
    }
    {
      name = "credential-bearing-endpoint";
      expected = "credential-free";
      settings = validDistributedSettings // {
        clusterEndpoints = [
          localEndpoint
          "http://user@${peerAddressA}:${toString testApiPort}${peerDataDirA}"
          peerEndpointB
        ];
      };
    }
    {
      name = "single-mode-endpoints";
      expected = "empty in single mode";
      settings = baseSettings // {
        clusterEndpoints = validEndpoints;
      };
    }
    {
      name = "zero-topology-timeout";
      expected = "must be positive";
      settings = validDistributedSettings // {
        topologyWaitTimeoutSeconds = 0;
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
  # r[verify onix.rustfs_cluster.validation]
  positiveErrors = lib.concatMap errorsFor [
    baseSettings
    validDistributedSettings
  ];
  missingNegativeCases = builtins.map (case: case.name) (
    builtins.filter (case: !case.found) negativeResults
  );
  negativeErrors = lib.concatMap (case: case.errors) negativeResults;
}
