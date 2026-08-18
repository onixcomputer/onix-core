# Static Server Access Control Specification Delta

## Purpose

Make static-server network exposure match the declared public or private access mode.

## ADDED Requirements

### Requirement: Private static servers are not globally exposed

r[onix.static_server.access.private] A static-server instance with `isPublic = false` MUST NOT open its service port on every firewall interface and MUST expose the backend only through an explicitly configured loopback or Tailscale-scoped path.

#### Scenario: Private firewall is interface scoped

r[onix.static_server.access.private.firewall]
- GIVEN a static-server instance has `isPublic = false`
- WHEN its NixOS configuration is evaluated
- THEN its port is absent from global `networking.firewall.allowedTCPPorts`
- AND any direct firewall allowance is restricted to the configured Tailscale interface

#### Scenario: Private service remains usable

r[onix.static_server.access.private.reachable]
- GIVEN a private static-server instance uses its configured local or Tailscale access path
- WHEN an authorized local proxy or Tailscale peer connects
- THEN the configured static content is reachable
- AND an ordinary non-Tailscale network peer cannot connect directly to the backend port

### Requirement: Public static servers remain explicitly public

r[onix.static_server.access.public] A static-server instance with `isPublic = true` MAY bind a non-loopback address and MUST declare any global firewall opening explicitly through the public-mode configuration.

#### Scenario: Public instance opens the configured port

r[onix.static_server.access.public.firewall]
- GIVEN a static-server instance has `isPublic = true`
- WHEN its NixOS configuration is evaluated
- THEN the configured port is globally allowed
- AND the service binds an address reachable through that public path

### Requirement: Access-mode validation uses the production module

r[onix.static_server.access.validation] The repository MUST verify positive public behavior and negative private exposure by instantiating the production static-server module rather than a hand-written lookalike service.

#### Scenario: Production module test detects policy regression

r[onix.static_server.access.validation.production]
- GIVEN the production module is evaluated in private and public fixtures
- WHEN its bind and firewall settings change
- THEN the fixtures assert the resulting access policy
- AND a private fixture fails if the port becomes globally allowed
