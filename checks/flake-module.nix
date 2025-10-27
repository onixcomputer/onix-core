# Checks module for onix-core VM integration tests
_: {
  perSystem = _: {
    checks = {
      # VM integration test disabled - complex external provider dependencies
      # opentofu-keycloak-vm-integration = import ./opentofu-keycloak-integration {
      #   inherit pkgs lib;
      # };
    };
  };
}
