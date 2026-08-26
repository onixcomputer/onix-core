{ lib }:
settings:
let
  minimumDistributedEndpointCount = 3;
  maximumErasureSetDriveCount = 16;
  minimumResourceWeight = 1;
  maximumResourceWeight = 10000;
  minimumNice = -20;
  maximumNice = 19;
  minimumOomScoreAdjust = -1000;
  maximumOomScoreAdjust = 1000;
  serviceNameIsSafe =
    builtins.isString settings.serviceName
    && builtins.match "[A-Za-z0-9_.@-]+" settings.serviceName != null;
  resourceWeightIsValid =
    weight: builtins.isInt weight && weight >= minimumResourceWeight && weight <= maximumResourceWeight;
  distributed = settings.mode == "distributed";
  endpoints = settings.clusterEndpoints;
  endpointCount = builtins.length endpoints;
  apiPortSegment = ":${toString settings.apiPort}/";
  expectedLocalEndpoint = "http://${settings.bindAddress}:${toString settings.apiPort}${settings.dataDir}";
  wildcardBindAddresses = [
    "0.0.0.0"
    "::"
    "[::]"
  ];
  endpointIsSafe =
    endpoint:
    endpoint != ""
    && lib.hasPrefix "http://" endpoint
    && lib.hasInfix apiPortSegment endpoint
    && !lib.hasSuffix apiPortSegment endpoint
    && !lib.hasInfix " " endpoint
    && !lib.hasInfix "@" endpoint
    && !lib.hasInfix "?" endpoint
    && !lib.hasInfix "#" endpoint;
in
{
  # r[impl onix.rustfs_cluster.topology]
  inherit
    distributed
    endpointCount
    expectedLocalEndpoint
    ;

  volumes = if distributed then lib.concatStringsSep " " endpoints else settings.dataDir;
  shareCredentials = distributed;
  distributedEnvironment = lib.optionalAttrs distributed {
    RUSTFS_ERASURE_SET_DRIVE_COUNT = toString endpointCount;
    RUSTFS_STARTUP_TOPOLOGY_WAIT_MODE = settings.topologyWaitMode;
    RUSTFS_STARTUP_TOPOLOGY_WAIT_TIMEOUT = toString settings.topologyWaitTimeoutSeconds;
  };

  assertions = [
    {
      assertion = serviceNameIsSafe;
      message = "rustfs serviceName must contain only systemd-safe letters, digits, dots, underscores, at signs, or hyphens";
    }
    {
      assertion = settings.dataDir != "" && lib.hasPrefix "/" settings.dataDir;
      message = "rustfs dataDir must be a non-empty absolute path";
    }
    {
      assertion = !lib.hasInfix " " settings.dataDir;
      message = "rustfs dataDir must not contain spaces because RUSTFS_VOLUMES uses spaces as separators";
    }
    {
      assertion = !settings.enableConsole || settings.apiPort != settings.consolePort;
      message = "rustfs apiPort and consolePort must differ when the console is enabled";
    }
    {
      assertion = distributed || endpoints == [ ];
      message = "rustfs clusterEndpoints must be empty in single mode";
    }
    {
      assertion = !distributed || endpointCount >= minimumDistributedEndpointCount;
      message = "rustfs distributed mode requires at least ${toString minimumDistributedEndpointCount} clusterEndpoints";
    }
    {
      assertion = !distributed || endpointCount <= maximumErasureSetDriveCount;
      message = "rustfs distributed clusterEndpoints exceed the maximum erasure set size of ${toString maximumErasureSetDriveCount}";
    }
    {
      assertion = !distributed || lib.unique endpoints == endpoints;
      message = "rustfs distributed clusterEndpoints must be unique and keep one canonical order";
    }
    {
      assertion = !distributed || !(builtins.elem settings.bindAddress wildcardBindAddresses);
      message = "rustfs distributed bindAddress must identify this node and must not be a wildcard";
    }
    {
      assertion = !distributed || builtins.elem expectedLocalEndpoint endpoints;
      message = "rustfs distributed clusterEndpoints must contain the exact local endpoint ${expectedLocalEndpoint}";
    }
    {
      assertion = !distributed || lib.all endpointIsSafe endpoints;
      message = "rustfs distributed clusterEndpoints must be credential-free HTTP URLs with the configured apiPort and absolute paths";
    }
    {
      assertion = !distributed || settings.topologyWaitTimeoutSeconds > 0;
      message = "rustfs topologyWaitTimeoutSeconds must be positive in distributed mode";
    }
    {
      assertion = resourceWeightIsValid settings.cpuWeight;
      message = "rustfs cpuWeight must be an integer between ${toString minimumResourceWeight} and ${toString maximumResourceWeight}";
    }
    {
      assertion = resourceWeightIsValid settings.ioWeight;
      message = "rustfs ioWeight must be an integer between ${toString minimumResourceWeight} and ${toString maximumResourceWeight}";
    }
    {
      assertion =
        builtins.isInt settings.nice && settings.nice >= minimumNice && settings.nice <= maximumNice;
      message = "rustfs nice must be an integer between ${toString minimumNice} and ${toString maximumNice}";
    }
    {
      assertion =
        builtins.isInt settings.oomScoreAdjust
        && settings.oomScoreAdjust >= minimumOomScoreAdjust
        && settings.oomScoreAdjust <= maximumOomScoreAdjust;
      message = "rustfs oomScoreAdjust must be an integer between ${toString minimumOomScoreAdjust} and ${toString maximumOomScoreAdjust}";
    }
  ];
}
