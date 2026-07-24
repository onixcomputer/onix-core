## Context

The repository has multiple validation surfaces, but they do not currently compose into a reliable gate. Root pytest walks ignored Pi worktrees, Buildbot's Nix package disables tests that now fail at import/API boundaries, the static-server VM test manually recreates implementation, and mypy's strict configuration is not clean over an explicit maintained scope.

## Decisions

### 1. Define one source-controlled validation manifest

**Choice:** The flake check graph will explicitly include root Python tests, each package's tests, the maintained type-check scope, and production-module integration tests. Generated, secret, build, cache, and agent-worktree paths will be excluded by reviewed patterns.

**Rationale:** Tool defaults and incidental discovery should not decide what CI verifies.

### 2. Make package tests hermetic

**Choice:** Repair public exports and cassette lookup for Buildbot tests, prohibit live network/token use by default, and enable `doCheck`. Other Python packages with behavior will receive both positive and negative unit tests as they enter the manifest.

**Rationale:** Disabled tests are not evidence.

### 3. Test production modules, not copies

**Choice:** Static-server VM/evaluation tests will import the repository module through its real Clan/NixOS interface and assert evaluated service/firewall behavior.

**Rationale:** A hand-written lookalike can pass while the production module is broken.

### 4. Adopt a bounded type-check rollout

**Choice:** Declare maintained Python source roots, fix their current errors, and wire mypy into the authoritative check. Expansion to legacy scripts is explicit rather than silently checking nothing or everything.

**Rationale:** A bounded clean contract is stronger than a strict configuration with no passing gate.

### 5. Keep local and CI invocation equivalent

**Choice:** Document one Nix-backed command that runs the same checks as CI without modifying files. Plain pytest from a Pi-enabled checkout must also collect deterministically.

**Rationale:** Developers need to reproduce failures before pushing.

## Risks / Trade-offs

- Enabling latent tests and type checks creates an initial repair workload.
- VCR cassettes need periodic intentional refresh without leaking credentials.
- Full VM tests are expensive, so fast evaluation checks should catch most policy regressions first.
