# Checks module for onix-core VM integration tests
_: {
  perSystem = _: {
    checks = {
      # Complete VM integration test - End-to-end keycloak + terraform validation
      # opentofu-keycloak-vm-integration = import ./opentofu-keycloak-integration {
      # inherit pkgs lib;
      # };
    };
  };
}
