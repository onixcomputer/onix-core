# Test configuration for the microvm clan service module
# Run with: nix-instantiate --eval modules/microvm/test.nix

let
  lib = (import <nixpkgs> { }).lib;

  # Mock inputs for testing

  # Import the module
  module = import ./default.nix { inherit lib; };

  # Test instance configuration

  # Extract the interface definition
  interface = module.roles.server.interface;

  # Check that required options exist
  hasRequiredOptions =
    interface.options ? vmName
    && interface.options ? vcpu
    && interface.options ? mem
    && interface.options ? interfaces;

in
{
  # Module metadata
  moduleName = module.manifest.name;
  moduleClass = module._class;

  # Interface validation
  hasInterface = module.roles ? server;
  hasPerInstance = module.roles.server ? perInstance;
  interfaceHasFreeform = interface ? freeformType;
  hasRequiredOptions = hasRequiredOptions;

  # Option types
  vmNameType = interface.options.vmName.type.description or "str";
  vcpuType = interface.options.vcpu.type.description or "int";
  memType = interface.options.mem.type.description or "int";

  # Default values
  autostartDefault = interface.options.autostart.default;
  vcpuDefault = interface.options.vcpu.default;
  memDefault = interface.options.mem.default;
  hypervisorDefault = interface.options.hypervisor.default;

  # Success message
  result =
    if hasRequiredOptions then
      "✓ Module structure validated successfully"
    else
      "✗ Module validation failed";
}
