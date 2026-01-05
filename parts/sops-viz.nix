# Analysis tools for infrastructure inspection
# Provides: acl, vars, tags, roster
# Access via: .#analysisTools.<system>.<tool> or .#packages.<system>.<tool>
_: {
  perSystem =
    { pkgs, ... }:
    let
      tools = {
        # Main ACL (Access Control List) viewer - replaces old sops-viz
        acl = pkgs.stdenv.mkDerivation {
          pname = "acl";
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

            # Copy Python scripts and implementation files
            cp $src/acl.py $out/bin/acl
            cp $src/sops_viz_simple_impl.py $out/bin/
            cp $src/sops_viz_rich_impl.py $out/bin/

            # Make main script executable
            chmod +x $out/bin/acl

            # Wrap with Python environment including all dependencies
            wrapProgram $out/bin/acl \
              --prefix PATH : ${pkgs.python3}/bin \
              --prefix PYTHONPATH : $out/bin:${pkgs.python3Packages.rich}/${pkgs.python3.sitePackages}:${pkgs.python3Packages.graphviz}/${pkgs.python3.sitePackages}


          '';
        };

        vars = pkgs.stdenv.mkDerivation {
          pname = "vars";
          version = "1.0.0";

          src = ../scripts;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          buildInputs = with pkgs; [
            python3
            python3Packages.rich
          ];

          installPhase = ''
                        mkdir -p $out/bin

                        # Copy the ownership analysis scripts and create unified command
                        cp $src/analyze-var-ownership-rich.py $out/bin/vars
                        cp $src/analyze-var-ownership.py $out/bin/vars-simple-impl.py

                        # Make them executable
                        chmod +x $out/bin/vars

                        # Create unified vars command that handles --basic flag
                        cat > $out/bin/vars-raw << 'EOF'
            #!/usr/bin/env python3
            import sys
            import subprocess
            import os
            from pathlib import Path

            # Check for --basic flag
            use_basic = '--basic' in sys.argv
            if use_basic:
                sys.argv.remove('--basic')

            # Get the directory where this script is located
            script_dir = Path(__file__).parent

            if use_basic:
                # Use simple implementation
                simple_script = script_dir / "vars-simple-impl.py"
                subprocess.run([sys.executable, str(simple_script)] + sys.argv[1:])
            else:
                # Use rich implementation (default)
                rich_script = script_dir / "vars-rich-impl.py"
                subprocess.run([sys.executable, str(rich_script)] + sys.argv[1:])
            EOF

                        # Replace the vars command with the wrapper
                        mv $out/bin/vars $out/bin/vars-rich-impl.py
                        mv $out/bin/vars-raw $out/bin/vars
                        chmod +x $out/bin/vars

                        # Wrap with Python environment
                        wrapProgram $out/bin/vars \
                          --prefix PATH : ${pkgs.python3}/bin \
                          --prefix PYTHONPATH : ${pkgs.python3Packages.rich}/${pkgs.python3.sitePackages}
          '';
        };

        tags = pkgs.stdenv.mkDerivation {
          pname = "tags";
          version = "1.0.0";

          src = ../scripts;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          buildInputs = with pkgs; [
            python3
            python3Packages.rich
          ];

          installPhase = ''
                        mkdir -p $out/bin

                        # Copy the machine analysis scripts and create unified command
                        cp $src/analyze-machines-rich.py $out/bin/tags
                        cp $src/analyze-machines.py $out/bin/tags-simple-impl.py

                        # Make them executable
                        chmod +x $out/bin/tags

                        # Create unified tags command that handles --basic flag
                        cat > $out/bin/tags-raw << 'EOF'
            #!/usr/bin/env python3
            import sys
            import subprocess
            import os
            from pathlib import Path

            # Check for --basic flag
            use_basic = '--basic' in sys.argv
            if use_basic:
                sys.argv.remove('--basic')

            # Get the directory where this script is located
            script_dir = Path(__file__).parent

            if use_basic:
                # Use simple implementation
                simple_script = script_dir / "tags-simple-impl.py"
                subprocess.run([sys.executable, str(simple_script)] + sys.argv[1:])
            else:
                # Use rich implementation (default)
                rich_script = script_dir / "tags-rich-impl.py"
                subprocess.run([sys.executable, str(rich_script)] + sys.argv[1:])
            EOF

                        # Replace the tags command with the wrapper
                        mv $out/bin/tags $out/bin/tags-rich-impl.py
                        mv $out/bin/tags-raw $out/bin/tags
                        chmod +x $out/bin/tags

                        # Wrap with Python environment
                        wrapProgram $out/bin/tags \
                          --prefix PATH : ${pkgs.python3}/bin \
                          --prefix PYTHONPATH : ${pkgs.python3Packages.rich}/${pkgs.python3.sitePackages}
          '';
        };

        roster = pkgs.stdenv.mkDerivation {
          pname = "roster";
          version = "1.0.0";

          src = ../scripts;

          nativeBuildInputs = [ pkgs.makeWrapper ];

          buildInputs = with pkgs; [
            python3
            python3Packages.rich
          ];

          installPhase = ''
                        mkdir -p $out/bin

                        # Copy the user analysis scripts and create unified command
                        cp $src/analyze-users-rich.py $out/bin/roster
                        cp $src/analyze-users.py $out/bin/roster-simple-impl.py

                        # Make them executable
                        chmod +x $out/bin/roster

                        # Create unified roster command that handles --basic flag
                        cat > $out/bin/roster-raw << 'EOF'
            #!/usr/bin/env python3
            import sys
            import subprocess
            import os
            from pathlib import Path

            # Check for --basic flag
            use_basic = '--basic' in sys.argv
            if use_basic:
                sys.argv.remove('--basic')

            # Get the directory where this script is located
            script_dir = Path(__file__).parent

            if use_basic:
                # Use simple implementation
                simple_script = script_dir / "roster-simple-impl.py"
                subprocess.run([sys.executable, str(simple_script)] + sys.argv[1:])
            else:
                # Use rich implementation (default)
                rich_script = script_dir / "roster-rich-impl.py"
                subprocess.run([sys.executable, str(rich_script)] + sys.argv[1:])
            EOF

                        # Replace the roster command with the wrapper
                        mv $out/bin/roster $out/bin/roster-rich-impl.py
                        mv $out/bin/roster-raw $out/bin/roster
                        chmod +x $out/bin/roster

                        # Wrap with Python environment
                        wrapProgram $out/bin/roster \
                          --prefix PATH : ${pkgs.python3}/bin \
                          --prefix PYTHONPATH : ${pkgs.python3Packages.rich}/${pkgs.python3.sitePackages}
          '';
        };
      };
    in
    {
      # Expose via custom transposed output
      analysisTools = tools;

      # Also expose via standard packages for backward compatibility
      packages = tools;
    };
}
