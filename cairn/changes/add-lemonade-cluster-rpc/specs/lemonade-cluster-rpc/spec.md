# lemonade-cluster-rpc Specification

## Purpose

Define opt-in Lemonade support for distributed llama.cpp inference over the selected Aspen fast-link network using llama.cpp RPC.

## Requirements

### Requirement: RDMA-capable llama.cpp RPC package

r[onix.lemonade.cluster_rpc.package] The system MUST build the ROCm llama.cpp package with RPC and libibverbs support so RPC can auto-negotiate RDMA when the runtime network supports it.

#### Scenario: Package exposes RPC binaries

r[onix.lemonade.cluster_rpc.package.binaries]
- GIVEN `pkgs.llamacpp-rocm-rpc` is built
- WHEN a maintainer inspects the package output
- THEN `llama-server` is present
- AND `llama-rpc-server` is present

#### Scenario: Package links libibverbs for RDMA negotiation

r[onix.lemonade.cluster_rpc.package.rdma]
- GIVEN the package is built on Linux
- WHEN the RPC backend is linked
- THEN libibverbs is available to the build
- AND `GGML_RPC_RDMA` is enabled for the RPC backend

### Requirement: Lemonade RPC schema

r[onix.lemonade.cluster_rpc.schema] The Lemonade service schema MUST expose opt-in settings for RPC client and RPC worker operation.

#### Scenario: RPC defaults are safe

r[onix.lemonade.cluster_rpc.schema.defaults]
- GIVEN no RPC settings are configured
- WHEN the Lemonade module evaluates
- THEN no RPC worker service is started
- AND no `--rpc` argument is added to the Lemonade backend args

#### Scenario: RPC settings are explicit

r[onix.lemonade.cluster_rpc.schema.explicit]
- GIVEN an operator enables RPC client or worker behavior
- WHEN the Lemonade module evaluates
- THEN the relevant port, bind host, worker endpoints, cache, device, and extra-argument settings are available as module settings

### Requirement: Cluster network metadata

r[onix.lemonade.cluster_rpc.network] The fast-link network tag MUST expose selected network metadata to NixOS modules without requiring those modules to parse `/etc` files.

#### Scenario: Network metadata includes selected addresses

r[onix.lemonade.cluster_rpc.network.metadata]
- GIVEN a host is tagged with the fast-link selector
- WHEN another module reads `config.onix.vllmClusterNetwork`
- THEN it can access the selected backend, interface, local address, head address, role, and worker addresses

### Requirement: Lemonade RPC client rendering

r[onix.lemonade.cluster_rpc.client] The Lemonade module MUST render llama.cpp `--rpc` endpoints into backend args when RPC client mode is enabled.

#### Scenario: Explicit endpoints render

r[onix.lemonade.cluster_rpc.client.explicit]
- GIVEN `clusterRpcClient` is enabled with explicit `clusterRpcWorkers`
- WHEN Lemonade renders its managed config files
- THEN the llama.cpp args include `--rpc` with those comma-separated endpoints

#### Scenario: Cluster-network endpoints render

r[onix.lemonade.cluster_rpc.client.derived]
- GIVEN `clusterRpcClient` is enabled and no explicit worker endpoints are set
- AND cluster-network metadata provides worker addresses
- WHEN Lemonade renders its managed config files
- THEN the llama.cpp args include `--rpc` endpoints derived from those worker addresses and `clusterRpcPort`

#### Scenario: Missing endpoints fail closed

r[onix.lemonade.cluster_rpc.client.missing_endpoints]
- GIVEN `clusterRpcClient` is enabled without explicit workers or cluster-network worker addresses
- WHEN the Lemonade module evaluates
- THEN evaluation fails with a clear missing-endpoints diagnostic

#### Scenario: Duplicate manual RPC args fail closed

r[onix.lemonade.cluster_rpc.client.duplicate_rpc]
- GIVEN `clusterRpcClient` is enabled and `extraArgs` already contains a manual `--rpc`
- WHEN the Lemonade module evaluates
- THEN evaluation fails with a clear duplicate-RPC diagnostic

### Requirement: Lemonade RPC worker service

r[onix.lemonade.cluster_rpc.worker] The Lemonade module MUST start a managed `lemonade-rpc-worker.service` when RPC worker mode is enabled.

#### Scenario: Worker binds to selected cluster address

r[onix.lemonade.cluster_rpc.worker.bind_selected]
- GIVEN `clusterRpcWorker` is enabled and cluster-network metadata provides a local address
- WHEN the worker service is rendered
- THEN `llama-rpc-server` binds to that local address and `clusterRpcPort`
- AND the firewall permits the RPC port

#### Scenario: Worker bind host can be explicit

r[onix.lemonade.cluster_rpc.worker.bind_explicit]
- GIVEN `clusterRpcWorker` is enabled with `clusterRpcBindHost`
- WHEN the worker service is rendered
- THEN `llama-rpc-server` binds to the explicit host and `clusterRpcPort`

#### Scenario: Worker without bind address fails closed

r[onix.lemonade.cluster_rpc.worker.no_bind]
- GIVEN `clusterRpcWorker` is enabled without `clusterRpcBindHost` or cluster-network local address
- WHEN the Lemonade module evaluates
- THEN evaluation fails with a clear bind-address diagnostic

### Requirement: Aspen Lemonade RPC wiring

r[onix.lemonade.cluster_rpc.aspen] The Aspen Lemonade inventory SHOULD configure `aspen1` as the RPC client/head and `aspen2` as an RPC worker using the selected fast-link network.

#### Scenario: Aspen head uses worker endpoint

r[onix.lemonade.cluster_rpc.aspen.head]
- GIVEN `aspen1` has the Lemonade RPC client enabled
- WHEN its Lemonade config is evaluated
- THEN its rendered llama.cpp args include an RPC endpoint for `aspen2` on the selected fast-link address

#### Scenario: Aspen worker exposes RPC service

r[onix.lemonade.cluster_rpc.aspen.worker]
- GIVEN `aspen2` has the Lemonade RPC worker enabled
- WHEN its NixOS configuration is evaluated
- THEN `lemonade-rpc-worker.service` is enabled
- AND the worker binds to `aspen2`'s selected fast-link address

### Requirement: Positive and negative validation

r[onix.lemonade.cluster_rpc.validation] The system MUST include positive and negative validation evidence for Lemonade RPC support.

#### Scenario: Positive validation passes

r[onix.lemonade.cluster_rpc.validation.positive]
- GIVEN the package, module, and Aspen inventory changes are present
- WHEN focused package and Nix evaluation checks run
- THEN the package builds
- AND the Aspen head renders RPC args
- AND the Aspen worker renders a worker service

#### Scenario: Negative validation passes

r[onix.lemonade.cluster_rpc.validation.negative]
- GIVEN invalid RPC client or worker configurations are evaluated
- WHEN focused negative checks run
- THEN each invalid configuration fails with the expected diagnostic
