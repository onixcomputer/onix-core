# Analysis tools for infrastructure inspection
# Provides: acl, vars, tags
# Access via: .#packages.<system>.<tool>
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
        cp $src/analyze-var-ownership-rich.py $out/bin/vars
        chmod +x $out/bin/vars

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
        cp $src/analyze-machines-rich.py $out/bin/tags
        chmod +x $out/bin/tags

        wrapProgram $out/bin/tags \
          --prefix PATH : ${pkgs.python3}/bin \
          --prefix PYTHONPATH : ${pkgs.python3Packages.rich}/${pkgs.python3.sitePackages}
      '';
    };

  };
in
{
  # Expose via standard packages
  packages = tools;
}
