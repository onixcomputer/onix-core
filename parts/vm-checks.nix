# VM integration checks for onix-core
# Separated from main checks for expensive/optional tests
_: {
  perSystem = _: {
    checks = {
      # Complete VM integration test - End-to-end keycloak + terraform validation
      # Commented out as these are expensive to run
      # opentofu-keycloak-vm-integration = import ../checks/opentofu-keycloak-integration {
      #   inherit pkgs lib;
      # };
    };
  };
}
