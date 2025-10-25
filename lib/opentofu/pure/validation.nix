# OpenTofu Configuration Validation Functions
#
# Pure functions for validating terranix configurations, generating
# configuration identifiers, and merging multiple configurations.
# These functions ensure configuration integrity and consistency.
{ lib }:

{
  # Validate terranix configuration structure
  #
  # Ensures that a terranix configuration is a valid, non-empty
  # attribute set. This provides basic structural validation before
  # configuration processing.
  #
  # Type: AttrSet -> AttrSet
  #
  # Example:
  #   validateTerranixConfig { resource = { }; }  # Valid, returns input
  #   validateTerranixConfig {}                   # Throws error
  #   validateTerranixConfig "invalid"            # Throws error
  validateTerranixConfig =
    config:
    if builtins.isAttrs config && config != { } then
      config
    else
      throw "validateTerranixConfig: Configuration must be a non-empty attribute set";

  # Generate deterministic configuration identifier
  #
  # Creates a stable hash-based identifier for a configuration that
  # can be used for caching, comparison, and change detection.
  #
  # Type: AttrSet -> String
  #
  # Example:
  #   generateConfigId { resource = { aws_instance = { }; }; }
  #   => "a1b2c3d4e5f6..." (SHA256 hash)
  generateConfigId = config: builtins.hashString "sha256" (builtins.toJSON config);

  # Merge multiple configurations into one
  #
  # Combines multiple terranix configurations using recursive merge,
  # allowing modular composition of infrastructure definitions.
  #
  # Type: [AttrSet] -> AttrSet
  #
  # Example:
  #   mergeConfigurations [{ resource.a = 1; } { resource.b = 2; }]
  #   => { resource = { a = 1; b = 2; }; }
  mergeConfigurations = configs: lib.foldl' lib.recursiveUpdate { } configs;
}
