_: {
  # This module is added only to the HOST package producer's extended NixOS
  # evaluation. Keep the ordinary NixOS/Clan Home Manager configuration intact.
  home-manager.sharedModules = [
    (
      { lib, ... }:
      let
        packagePolicy = import ./package-policy.nix { inherit lib; };
      in
      {
        # The pinned Home Manager declaration has no `apply`; add it here so
        # the policy filters the merged package list before both home.path and
        # activationPackage are built.
        options.home.packages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          apply = packagePolicy.keepPackages;
        };
        options.onixos.nativeHost = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Produce the retained Home Manager configuration without Nix tooling.";
        };

        config = {
          onixos.nativeHost = true;
          # An explicit options declaration requires explicit config as well.
          # The native host installs useUserPackages through its own profile
          # symlink service. Home Manager must not perform Nix profile or GC-root
          # operations on the target.
          nix.enable = lib.mkForce false;
          home.activationGenerateGcRoot = lib.mkForce false;
          home.activation.installPackages = lib.mkForce (lib.hm.dag.entryAfter [ "writeBoundary" ] "");

          # `direnv` itself remains useful; only its Nix-specific integration is
          # unavailable on a host with no Nix daemon or CLI.
          programs.direnv.nix-direnv.enable = lib.mkForce false;
        };
      }
    )
  ];
}
