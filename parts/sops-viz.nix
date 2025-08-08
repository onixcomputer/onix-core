_: {
  perSystem =
    { pkgs, ... }:
    {
      packages = {
        sops-viz = pkgs.stdenv.mkDerivation {
          pname = "sops-viz";
          version = "1.0.0";

          src = ../scripts/sops-viz;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          buildInputs = with pkgs; [
            python3
            python3Packages.rich
            python3Packages.graphviz
            graphviz
          ];

          installPhase = ''
            mkdir -p $out/bin

            # Copy Python scripts
            cp $src/sops-viz-simple.py $out/bin/sops-viz
            cp $src/sops-viz-rich.py $out/bin/sops-viz-rich

            # Make them executable
            chmod +x $out/bin/sops-viz
            chmod +x $out/bin/sops-viz-rich

            # Wrap with Python environment
            wrapProgram $out/bin/sops-viz \
              --prefix PATH : ${pkgs.python3}/bin

            wrapProgram $out/bin/sops-viz-rich \
              --prefix PATH : ${pkgs.python3}/bin \
              --prefix PYTHONPATH : ${pkgs.python3Packages.rich}/${pkgs.python3.sitePackages}:${pkgs.python3Packages.graphviz}/${pkgs.python3.sitePackages}

            # Create sops-viz-dot helper
            cat > $out/bin/sops-viz-dot << 'EOF'
            #!/usr/bin/env bash
            if [ -z "$1" ]; then
              echo "Usage: sops-viz-dot <dot-file> [output-format]"
              echo "  Converts DOT file to image format (default: png)"
              echo "  Supported formats: png, svg, pdf"
              echo ""
              echo "Example:"
              echo "  sops-viz-dot sops_hierarchy.dot       # Creates sops_hierarchy.png"
              echo "  sops-viz-dot sops_hierarchy.dot svg   # Creates sops_hierarchy.svg"
              exit 1
            fi

            DOT_FILE="$1"
            FORMAT="''${2:-png}"
            OUTPUT="''${DOT_FILE%.dot}.$FORMAT"

            if [ ! -f "$DOT_FILE" ]; then
              echo "Error: DOT file '$DOT_FILE' not found"
              exit 1
            fi

            ${pkgs.graphviz}/bin/dot -T"$FORMAT" "$DOT_FILE" -o "$OUTPUT"
            echo "✓ Generated $OUTPUT"
            EOF

            chmod +x $out/bin/sops-viz-dot
          '';
        };

        sops-ownership = pkgs.stdenv.mkDerivation {
          pname = "sops-ownership";
          version = "1.0.0";

          src = ../scripts;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          buildInputs = with pkgs; [
            python3
            python3Packages.rich
          ];

          installPhase = ''
            mkdir -p $out/bin

            # Copy the ownership analysis scripts
            cp $src/analyze-var-ownership.py $out/bin/sops-ownership
            cp $src/analyze-var-ownership-rich.py $out/bin/sops-ownership-rich

            # Make them executable
            chmod +x $out/bin/sops-ownership
            chmod +x $out/bin/sops-ownership-rich

            # Wrap with Python environment
            wrapProgram $out/bin/sops-ownership \
              --prefix PATH : ${pkgs.python3}/bin

            wrapProgram $out/bin/sops-ownership-rich \
              --prefix PATH : ${pkgs.python3}/bin \
              --prefix PYTHONPATH : ${pkgs.python3Packages.rich}/${pkgs.python3.sitePackages}
          '';
        };

        machines-analyzer = pkgs.stdenv.mkDerivation {
          pname = "machines-analyzer";
          version = "1.0.0";

          src = ../scripts;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          buildInputs = with pkgs; [
            python3
            python3Packages.rich
          ];

          installPhase = ''
            mkdir -p $out/bin

            # Copy the machine analysis scripts
            cp $src/analyze-machines.py $out/bin/machines-analyzer
            cp $src/analyze-machines-rich.py $out/bin/machines-analyzer-rich

            # Make them executable
            chmod +x $out/bin/machines-analyzer
            chmod +x $out/bin/machines-analyzer-rich

            # Wrap with Python environment
            wrapProgram $out/bin/machines-analyzer \
              --prefix PATH : ${pkgs.python3}/bin

            wrapProgram $out/bin/machines-analyzer-rich \
              --prefix PATH : ${pkgs.python3}/bin \
              --prefix PYTHONPATH : ${pkgs.python3Packages.rich}/${pkgs.python3.sitePackages}
          '';
        };

        users-analyzer = pkgs.stdenv.mkDerivation {
          pname = "users-analyzer";
          version = "1.0.0";

          src = ../scripts;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          buildInputs = with pkgs; [
            python3
            python3Packages.rich
          ];

          installPhase = ''
            mkdir -p $out/bin

            # Copy the user analysis scripts
            cp $src/analyze-users.py $out/bin/users-analyzer
            cp $src/analyze-users-rich.py $out/bin/users-analyzer-rich

            # Make them executable
            chmod +x $out/bin/users-analyzer
            chmod +x $out/bin/users-analyzer-rich

            # Wrap with Python environment
            wrapProgram $out/bin/users-analyzer \
              --prefix PATH : ${pkgs.python3}/bin

            wrapProgram $out/bin/users-analyzer-rich \
              --prefix PATH : ${pkgs.python3}/bin \
              --prefix PYTHONPATH : ${pkgs.python3Packages.rich}/${pkgs.python3.sitePackages}
          '';
        };
      };
    };
}
