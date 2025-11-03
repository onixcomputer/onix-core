{
  programs.git = {
    enable = true;

    settings = {
      user = {
        name = "brittonr";
        email = "b@robitzs.ch";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      core.editor = "hx";
      aliases = {
        o = "checkout";
        c = "commit";
        s = "status";
        b = "branch";
        h = "log --pretty=format:'%h %ad | %s%d [%an]' --graph --date=short";
        t = "cat-file -t";
        d = "cat-file -p";
      };
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
