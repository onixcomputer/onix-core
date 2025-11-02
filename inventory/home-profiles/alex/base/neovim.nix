{ inputs, pkgs, ... }:
{
  programs.neovim.enable = false;

  home = {
    packages = [
      inputs.adeci-nixvim.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];

    shellAliases = {
      vim = "nvim";
      vi = "nvim";
    };

    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };
}
