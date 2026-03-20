{ config, ... }:
let
  c = config.theme.data;
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

    includes = [
      { path = "~/.config/git/noctalia-delta-colors"; }
    ];

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
      # Theme colors
      syntax-theme = "base16";
      plus-style = "syntax \"${c.green.hex}\"";
      minus-style = "syntax \"${c.red.hex}\"";
      plus-emph-style = "syntax \"${c.green.hex}\"";
      minus-emph-style = "syntax \"${c.red.hex}\"";
      line-numbers-plus-style = c.green.hex;
      line-numbers-minus-style = c.red.hex;
      line-numbers-left-style = c.comment.hex;
      line-numbers-right-style = c.comment.hex;
      line-numbers-zero-style = c.comment.hex;
      file-style = "${c.orange.hex} bold";
      file-decoration-style = "${c.orange.hex} ul";
      hunk-header-style = "${c.blue.hex} bold";
      hunk-header-decoration-style = "${c.blue.hex} box";
    };
  };
}
