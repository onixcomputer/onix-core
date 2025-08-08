{
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting # Disable greeting

      function cc
        bat $argv | wl-copy
      end
    '';
    shellAliases = {
      # ll = "ls -l";
      # la = "ls -la";
      ".." = "cd ..";
      "..." = "cd ../..";
      "lg" = "lazygit";
      "cat" = "bat";
      "cu" = "clan m update $hostname";
    };
  };
}
