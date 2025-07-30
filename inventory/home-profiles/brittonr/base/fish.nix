{
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting # Disable greeting
    '';
    shellAliases = {
      # ll = "ls -l";
      # la = "ls -la";
      ".." = "cd ..";
      "..." = "cd ../..";
    };
  };
}
