# Private RustFS Cluster Specification

## Purpose

Provide one private S3-compatible namespace across selected Onix machines without claiming production readiness.

## ADDED Requirements

### Requirement: Nodes share one topology

r[onix.rustfs_cluster.topology] Every distributed RustFS node MUST receive the same ordered URL endpoint list and erasure-set size.

#### Scenario: Three-node configuration

r[onix.rustfs_cluster.topology.three_node]
- GIVEN three selected machines with one admitted storage path each
- WHEN the RustFS service configuration is evaluated
- THEN every node receives all three endpoint URLs in the same order
- AND each node identifies exactly one endpoint as local

### Requirement: One service composes the cluster

r[onix.rustfs_cluster.composition] The inventory MUST model the distributed deployment as one Clan service instance spanning all selected machines.

#### Scenario: Inventory expansion

r[onix.rustfs_cluster.composition.inventory]
- GIVEN the RustFS cluster instance
- WHEN Clan expands the server role
- THEN `aspen1`, `aspen3`, and `britton-desktop` receive the cluster service
- AND no separate standalone RustFS instance remains assigned to those machines

### Requirement: Cluster credentials are shared

r[onix.rustfs_cluster.credentials] All nodes MUST receive one Clan-generated encrypted credential file for the cluster instance.

#### Scenario: Peer startup

r[onix.rustfs_cluster.credentials.shared]
- GIVEN the cluster credential generator
- WHEN Clan generates and deploys its output
- THEN every selected node receives the same access and secret keys
- AND no plaintext credential enters the Nix store

### Requirement: Exposure stays private

r[onix.rustfs_cluster.security] RustFS client and peer ports MUST be admitted only on `tailscale0`.

#### Scenario: Network admission

r[onix.rustfs_cluster.security.tailnet]
- GIVEN a configured API and console port
- WHEN NixOS lowers firewall policy
- THEN those ports are allowed on `tailscale0`
- AND they are not added to the global allowed-port list

#### Scenario: Anonymous request

r[onix.rustfs_cluster.security.anonymous]
- GIVEN a running cluster
- WHEN a client sends an unauthenticated object request
- THEN RustFS rejects the request

### Requirement: Invalid topology fails evaluation

r[onix.rustfs_cluster.validation] Pure configuration validation MUST reject a topology that can create a partial, divergent, or unsafe cluster.

#### Scenario: Missing endpoint

r[onix.rustfs_cluster.validation.missing]
- GIVEN distributed mode with fewer than three endpoints
- WHEN topology validation runs
- THEN evaluation fails with an endpoint-count error

#### Scenario: Duplicate endpoint

r[onix.rustfs_cluster.validation.duplicate]
- GIVEN distributed mode with a duplicate endpoint URL
- WHEN topology validation runs
- THEN evaluation fails with a uniqueness error

#### Scenario: Local endpoint mismatch

r[onix.rustfs_cluster.validation.local]
- GIVEN a node bind address, API port, and data path
- AND their derived URL is absent from the shared topology
- WHEN topology validation runs
- THEN evaluation fails with a local-membership error

### Requirement: Rollout preserves rollback state

r[onix.rustfs_cluster.rollout] The first distributed rollout MUST use new empty cluster directories and MUST retain standalone state until runtime acceptance succeeds.

#### Scenario: Coordinated cutover

r[onix.rustfs_cluster.rollout.coordinated]
- GIVEN all three machine configurations build successfully
- AND every selected machine is reachable
- WHEN the cluster rollout starts
- THEN all nodes switch to the shared topology in one bounded operation
- AND the previous standalone directories remain unchanged

### Requirement: Runtime proves one namespace

r[onix.rustfs_cluster.runtime] Acceptance MUST prove that each node serves one shared object namespace.

#### Scenario: Cross-node object flow

r[onix.rustfs_cluster.runtime.cross_node]
- GIVEN a bucket and object created through one node
- WHEN authenticated clients read and list them through the other nodes
- THEN every node returns the same bucket and object data

### Requirement: Failure claims require observation

r[onix.rustfs_cluster.failure] The deployment MUST NOT claim node-loss tolerance until a live one-node outage test passes.

#### Scenario: One node stops

r[onix.rustfs_cluster.failure.one_node]
- GIVEN a healthy three-node cluster with verified test data
- WHEN one RustFS node stops
- THEN the remaining nodes continue accepted reads and writes
- AND the stopped node rejoins without changing the shared namespace
