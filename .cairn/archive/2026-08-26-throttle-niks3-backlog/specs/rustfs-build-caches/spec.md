## MODIFIED Requirements

### Requirement: Fleet auto-upload
r[onix.rustfs_build_caches.uploaders] The three RustFS nodes MUST run crash-safe niks3 auto-upload daemons with only the shared API token and a bounded single-upload worker per node.

#### Scenario: Queue completed builds
r[onix.rustfs_build_caches.uploaders.queue]
- GIVEN Nix completes a build on a configured node
- WHEN the post-build hook emits its store paths
- THEN the local uploader queues and sends them to niks3
- AND each node uploads no more than one path at a time

#### Scenario: Server is unavailable
r[onix.rustfs_build_caches.uploaders.unavailable]
- GIVEN niks3 is temporarily unavailable
- WHEN a Nix build completes
- THEN the build result remains valid
- AND the uploader retains or retries queued work without blocking normal substitution

#### Scenario: A large backlog makes bounded progress
r[onix.rustfs_build_caches.uploaders.backlog]
- GIVEN one or more nodes have durable queued paths
- WHEN one node's upload worker runs
- THEN queue depth decreases without deleting pending live entries
- AND runtime evidence records any coordinator self-fence and its recovery after upload pressure stops
