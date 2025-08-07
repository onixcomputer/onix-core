{
  programs.git = {
    enable = true;
    userName = "adeci";
    userEmail = "alex.decious@gmail.com";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };
}
