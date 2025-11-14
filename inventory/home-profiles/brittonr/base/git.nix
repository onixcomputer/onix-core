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
      # Onix Dark colors
      syntax-theme = "base16";
      plus-style = "syntax \"#44ff44\"";
      minus-style = "syntax \"#ff4444\"";
      plus-emph-style = "syntax \"#44ff44\"";
      minus-emph-style = "syntax \"#ff4444\"";
      line-numbers-plus-style = "#44ff44";
      line-numbers-minus-style = "#ff4444";
      line-numbers-left-style = "#595959";
      line-numbers-right-style = "#595959";
      line-numbers-zero-style = "#595959";
      file-style = "#ff6600 bold";
      file-decoration-style = "#ff6600 ul";
      hunk-header-style = "#4488ff bold";
      hunk-header-decoration-style = "#4488ff box";
    };
  };
}
