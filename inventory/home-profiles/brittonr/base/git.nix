{
  programs.git = {
    enable = true;
    userName = "brittonr";
    userEmail = "b@robitzs.ch";

    aliases = {
      o = "checkout";
      c = "commit";
      s = "status";
      b = "branch";
      h = "log --pretty=format:'%h %ad | %s%d [%an]' --graph --date=short";
      t = "cat-file -t";
      d = "cat-file -p";
    };

    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      core.editor = "hx";
    };

    ignores = [
      ".DS_Store"
      "*.swp"
      "*~"
      ".direnv"
      ".envrc"
    ];

    delta = {
      enable = true;
      options = {
        navigate = true;
        light = false;
        side-by-side = true;
        line-numbers = true;
        syntax-theme = "Dracula";
      };
    };
  };
}
