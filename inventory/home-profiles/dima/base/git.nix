{
  programs.git = {
    enable = true;
    userName = "dimitridecious";
    userEmail = "dima.decious@gmail.com";
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };
}
