{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "dimitridecious";
        email = "dima.decious@gmail.com";
      };
      init.defaultBranch = "main";
      pull.rebase = true;
    };
  };
}
