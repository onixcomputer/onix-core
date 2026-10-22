# Radicle Node Hosting Specification Delta

## MODIFIED Requirements

### Requirement: Reviewed Radicle package baseline

r[onix.radicle_node.package] `onix-core` MUST package a reviewed Radicle release at version `1.9.1` or later and MUST reject a deployment whose signed-reference feature policy is weaker than `parent`. The repository checks MUST pin the exact reviewed `radicle-node` release (`1.10.3`) and `radicle-httpd` source identity (`0.28.0`), both accepted on 2026-10-21, so that an unreviewed version fails until an operator accepts it.

#### Scenario: Reviewed package is admitted

r[onix.radicle_node.package.admitted]
- GIVEN the configured Radicle packages are the reviewed releases and meet the signed-reference feature policy
- WHEN the package and service configuration are evaluated
- THEN the node and HTTP components MUST be available from one recorded package identity
- AND the bootstrap evidence MUST keep the versions and feature policy admitted at bootstrap

#### Scenario: Unsafe package is rejected

r[onix.radicle_node.package.rejected]
- GIVEN the configured package is older than the named minimum or enables a weaker signed-reference feature
- WHEN deployment configuration is evaluated
- THEN evaluation MUST fail before creating a deployable service
