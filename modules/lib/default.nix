{
  lib,
  pkgs,
  config,
}:

{
  opentofu = {
    # Core OpenTofu library functionality
    lib = import ./opentofu/default.nix { inherit lib pkgs config; };

    # Enhanced terranix support
    terranix = import ./opentofu/terranix.nix { inherit lib pkgs; };
  };
}
