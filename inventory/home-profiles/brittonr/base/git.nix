{ config, ... }:
let
  c = config.colors;
in
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
      plus-style = "syntax \"${c.green}\"";
      minus-style = "syntax \"${c.red}\"";
      plus-emph-style = "syntax \"${c.green}\"";
      minus-emph-style = "syntax \"${c.red}\"";
      line-numbers-plus-style = c.green;
      line-numbers-minus-style = c.red;
      line-numbers-left-style = c.comment;
      line-numbers-right-style = c.comment;
      line-numbers-zero-style = c.comment;
      file-style = "${c.orange} bold";
      file-decoration-style = "${c.orange} ul";
      hunk-header-style = "${c.blue} bold";
      hunk-header-decoration-style = "${c.blue} box";
    };
  };
}
