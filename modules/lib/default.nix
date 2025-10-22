{
  lib,
  pkgs,
  config,
}:

{
  opentofu = {
    # Re-export deployment patterns
    deployment = import ./opentofu/deployment.nix { inherit lib pkgs; };

    # Re-export all OpenTofu modules
    garage = import ./opentofu/garage-backend.nix { inherit lib pkgs config; };
    backends = import ./opentofu/backends.nix { inherit lib pkgs config; };
    terranix = import ./opentofu/terranix.nix { inherit lib pkgs; };
    service = import ./opentofu/service.nix { inherit lib pkgs config; };

    # Convenience functions
    generateOpenTofuService =
      (import ./opentofu/service.nix { inherit lib pkgs config; }).generateOpenTofuService;
    mkGarageDeployment =
      (import ./opentofu/garage-backend.nix { inherit lib pkgs config; }).mkGarageBlockingDeployment;
  };
}
