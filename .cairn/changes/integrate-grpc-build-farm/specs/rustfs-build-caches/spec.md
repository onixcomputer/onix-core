## MODIFIED Requirements

### Requirement: Fleet upload maintenance

r[onix.rustfs_build_caches.uploaders] Configured build nodes MUST retain durable niks3 queues, but automatic post-build hook activation MUST remain disabled until continuous coordination availability is proven. Explicitly admitted gRPC farm publication is a separate automatic path to the isolated cache and MUST NOT drain these queues.

#### Scenario: Complete a non-farm Nix build

r[onix.rustfs_build_caches.uploaders.disabled]
- GIVEN no upload maintenance window is active
- WHEN Nix completes a build outside the gRPC farm
- THEN the build succeeds without starting a niks3 queue uploader
- AND existing durable queue rows remain unchanged

#### Scenario: Admit a manual queue drain

r[onix.rustfs_build_caches.uploaders.maintenance]
- GIVEN an operator selects one node for maintenance
- AND the maintenance marker exists
- AND every configured guard endpoint is healthy
- WHEN the operator starts the uploader socket and service
- THEN at most one upload request runs at a time
- AND the durable queue makes bounded progress

#### Scenario: Reject unsafe drain admission

r[onix.rustfs_build_caches.uploaders.reject]
- GIVEN the maintenance marker is absent or one guard endpoint is unhealthy
- WHEN the uploader service starts
- THEN systemd rejects the start before queue work begins
- AND no durable queue row is deleted
