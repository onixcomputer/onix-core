# Checks module for onix-core VM integration tests
{ ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    {
      checks = {
        # Complete VM integration test - End-to-end keycloak + terraform validation
        opentofu-keycloak-vm-integration = import ./opentofu-keycloak-integration {
          inherit pkgs lib;
        };
      };
    };
}
