{ lib }:
settings:
let
  minimumDistributedEndpointCount = 3;
  maximumErasureSetDriveCount = 16;
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
  ];
}
