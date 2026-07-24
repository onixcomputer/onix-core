## Context

The static-server module conflates application metadata (`isPublic`) with no actual network policy. Both public and private instances use a wildcard bind and `networking.firewall.allowedTCPPorts`, which opens the port on all interfaces. The inventory deploys both modes, so the discrepancy is operational rather than hypothetical.

## Decisions

### 1. Derive firewall policy from access mode

**Choice:** Public instances may add their port to global `allowedTCPPorts`. Private instances must not do so; they will either bind loopback for a local reverse proxy or permit the port only on the configured Tailscale interface.

**Rationale:** Interface-scoped firewall policy enforces the advertised distinction even when a backend needs a wildcard bind.

### 2. Make the private access path explicit

**Choice:** Extend the schema with typed bind/interface settings or derive a reviewed default. Module assertions will reject combinations where `isPublic = false` still produces unrestricted exposure.

**Rationale:** Security should follow evaluated configuration, not page text or operator convention.

### 3. Preserve public behavior deliberately

**Choice:** `isPublic = true` retains externally reachable binding and global firewall access. Existing public inventory receives a positive regression test.

**Rationale:** The repair should not accidentally make the public demo unreachable.

### 4. Test the production module

**Choice:** Evaluation and VM tests will instantiate the actual static-server module. A two-node or interface-aware test will verify that private mode remains locally/Tailscale reachable but is denied over an ordinary interface.

**Rationale:** The current hand-written VM service cannot detect module regressions.

## Risks / Trade-offs

- Interface names may vary; the schema/default must align with the repository's Tailscale module contract.
- Hosts without Tailscale need a clear loopback/proxy mode or an evaluation error.
- Firewall evaluation proves policy shape; a VM network test is still needed for behavioral evidence.
