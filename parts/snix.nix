{ inputs, ... }:
{
  perSystem = { system, pkgs, ... }:
    let
      # Import the snix depot with the required arguments
      snix = import inputs.snix {
        localSystem = system;
        # You can pass additional configuration if needed
        nixpkgsConfig = {};
      };
    in
    {
      # Expose snix packages for use in other parts of your flake
      packages = {
        # Example: Expose specific snix tools
        inherit (snix.tools)
          depotfmt
          gerrit-cli
          magrathea;

        # Expose Tvix/Snix CLI components
        snix-cli = pkgs.runCommand "snix-cli" {
          buildInputs = [ pkgs.makeWrapper ];
        } ''
          mkdir -p $out/bin
          ln -s ${snix.snix.cli}/bin/snix $out/bin/snix-cli
          ln -s ${snix.snix.cli}/bin/snix $out/bin/snix
        '';
        snix-eval = snix.snix.eval;
        snix-build = snix.snix.build;
        nar-bridge = snix.snix."nar-bridge" or null;
      };

      # Add snix tools to your development shell
      devShells.snix = pkgs.mkShell {
        packages = with snix; [
          # Tools from snix depot
          tools.depotfmt
          tools.gerrit-cli
          tools.magrathea

          # Snix/Tvix CLI
          snix.cli
        ];

        shellHook = ''
          echo "Snix development environment loaded"
          echo "Available commands:"
          echo "  - snix: Tvix/Snix CLI (experimental Nix implementation in Rust)"
          echo "  - depotfmt: Format Nix files according to depot style"
          echo "  - gerrit-cli: Interact with Gerrit code review"
          echo "  - mg: Magrathea build tool"
        '';
      };
    };
}