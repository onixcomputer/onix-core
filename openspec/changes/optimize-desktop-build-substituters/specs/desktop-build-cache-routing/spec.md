## ADDED Requirements

### Requirement: Desktop substituter order is deduplicated and intentional [r[desktop-cache.substituter-order]]
`britton-desktop` MUST expose a deduplicated, intentionally ordered substituter list for Nix builds.

#### Scenario: resolved substituters have no duplicates [r[desktop-cache.substituter-order.no-duplicates]]
- GIVEN the `britton-desktop` Nix configuration is evaluated or deployed
- WHEN the resolved `substituters` setting is inspected
- THEN each substituter URL appears at most once
- AND the order matches the documented desktop cache-routing policy

#### Scenario: local cache ordering is documented [r[desktop-cache.substituter-order.local-cache]]
- GIVEN `http://aspen1.local:5000` is present in the substituter list
- WHEN the implementation documentation or config comment is inspected
- THEN it explains whether the local cache is preferred before public caches or used as a later fallback

### Requirement: Trusted substituter policy remains explicit [r[desktop-cache.trust-policy]]
`britton-desktop` MUST keep trusted substituter configuration explicit when cache routing changes so new cache endpoints are not silently trusted.

#### Scenario: trusted caches are inspected [r[desktop-cache.trust-policy.resolved]]
- GIVEN the desktop cache-routing configuration is evaluated
- WHEN `trusted-substituters` and related trusted public keys are inspected
- THEN every non-default trusted cache is intentionally listed
- AND no new trusted cache is added without review evidence in the change

### Requirement: Heavy builds can avoid local compilation [r[desktop-cache.remote-only-builds]]
The desktop build workflow MUST document a remote-builder-only path for heavyweight builds that should fetch substitutes or schedule remotely instead of consuming local compiler resources.

#### Scenario: remote-only probe does not start local builds [r[desktop-cache.remote-only-builds.probe]]
- GIVEN remote builders are reachable from `britton-desktop`
- WHEN the operator runs the documented `nix build --max-jobs 0` probe
- THEN Nix either substitutes or schedules builds remotely
- AND local compilation is not used for the probed derivation

#### Scenario: unavailable builders fail clearly [r[desktop-cache.remote-only-builds.unavailable]]
- GIVEN no suitable substitute exists and remote builders are unavailable
- WHEN the remote-only build probe runs
- THEN the command fails with a remote-builder/substitute availability error instead of falling back to unrestricted local compilation
