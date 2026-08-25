## Phase 1: Cluster contract

- [x] [serial] Record the cluster topology, authority boundary, rollback boundary, experimental status, and non-claims. r[onix.rustfs_cluster.topology]
- [x] [serial] Add the pure topology core and typed settings for single-node and distributed modes. r[onix.rustfs_cluster.topology]
- [x] [parallel] Add positive and negative fixtures for topology and credential-sharing policy. r[onix.rustfs_cluster.validation]

## Phase 2: Declarative composition

- [x] [serial] Replace the three standalone inventory instances with one three-machine cluster instance. r[onix.rustfs_cluster.composition]
- [x] [serial] Generate one shared Clan credential and remove orphaned standalone generator outputs. r[onix.rustfs_cluster.credentials]
- [x] [parallel] Verify Tailnet-only firewall rules, private state directories, service hardening, and identical endpoint lists. r[onix.rustfs_cluster.security]

## Phase 3: Build and rollout

- [x] [serial] Run focused Nickel, topology, module, inventory, vars, and machine evaluation checks. r[onix.rustfs_cluster.validation]
- [x] [serial] Pin and build the upstream `nix-eval-jobs` Nix 2.36 port with the pinned Onix Nix compatibility patch. r[onix.rustfs_cluster.rollout]
- [x] [serial] Build all three machine configurations without changing the live services. r[onix.rustfs_cluster.rollout]
- [ ] [serial] Confirm Aspen1 reachability, preserve standalone state, and deploy all nodes as one coordinated cutover. r[onix.rustfs_cluster.rollout]

## Phase 4: Runtime evidence

- [ ] [serial] Verify one namespace through every node with authenticated S3 create, write, read, list, and cleanup operations. r[onix.rustfs_cluster.runtime]
- [ ] [parallel] Verify anonymous requests fail and cluster credentials match on all nodes without exposing secret values. r[onix.rustfs_cluster.security]
- [ ] [serial] Verify coordinated restart and one-node outage recovery before claiming node-loss tolerance. r[onix.rustfs_cluster.failure]
- [ ] [serial] Record bounded evidence, sync accepted requirements, archive the change, and commit verified results. r[onix.rustfs_cluster.validation]
