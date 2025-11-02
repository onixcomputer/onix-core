{
  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "adeci";
        email = "alex.decious@gmail.com";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };

    ignores = [
      ".DS_Store"
      "*.swp"
      "*~"
      ".direnv"
      ".envrc"
    ];
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      light = false;
      side-by-side = true;
      line-numbers = true;
      syntax-theme = "Dracula";
    };
  };
}
