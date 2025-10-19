{ inputs, pkgs, ... }:
let
  mcpConfig = inputs.mcp-servers-nix.lib.mkConfig pkgs {
    programs = {
      git = {
        enable = true;
      };
      github = {
        enable = true;
      };
      fetch = {
        enable = true;
      };
      memory = {
        enable = true;
      };
      context7 = {
        enable = true;
      };
      serena = {
        enable = true;
      };
      playwright = {
        enable = true;
      };
    };
  };

  # Wrap the config file in a derivation
  mcpConfigPackage = pkgs.runCommand "mcp-config" { } ''
    mkdir -p $out/etc/claude
    cp ${mcpConfig} $out/etc/claude/claude_desktop_config.json
  '';
in
{
  nixpkgs.overlays = [
    inputs.mcp-servers-nix.overlays.default
  ];

  environment.systemPackages = [ mcpConfigPackage ];

  # Also make the config available at a standard location
  environment.etc."claude/claude_desktop_config.json".source = mcpConfig;
}
