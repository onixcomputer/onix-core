{
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting # Disable greeting

      # Import systemd environment (for SSH_AUTH_SOCK from gnome-keyring)
      if command -v systemctl &> /dev/null
        set -x SSH_AUTH_SOCK (systemctl --user show-environment | grep SSH_AUTH_SOCK | cut -d= -f2)
      end

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
