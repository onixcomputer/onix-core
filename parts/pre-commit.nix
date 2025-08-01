{ inputs, ... }:
{
  imports = [ inputs.pre-commit-hooks-nix.flakeModule ];

  perSystem =
    { config, ... }:
    {
      pre-commit = {
        check.enable = true;

        settings = {
          hooks = {
            # Core formatting using existing treefmt setup
            treefmt = {
              enable = true;
              package = config.treefmt.build.wrapper;
              pass_filenames = false;
            };

            # Nix-specific linting
            statix.enable = true;
            deadnix.enable = true;
          };

          # Exclude files that shouldn't be checked
          excludes = [
            "^vars/" # SOPS-managed secrets
            "^sops/" # SOPS configuration
            "\\.age$" # Age-encrypted files
            "\\.png$|\\.jpg$|\\.svg$" # Images
            "flake\\.lock$" # Generated file
            "^archive/" # Legacy code
          ];
        };
      };

      # Note: Development shell integration is handled in devshells.nix
    };
}
