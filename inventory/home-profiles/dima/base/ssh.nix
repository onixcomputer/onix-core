_: {
  # using gnome-keyring
  services.ssh-agent.enable = false;

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    extraConfig = ''
      AddressFamily inet
    '';

    matchBlocks = {
      "*" = {
        addKeysToAgent = "yes";
      };

      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/nixos_key";
        identitiesOnly = true;
      };
      "gitlab.com" = {
        hostname = "gitlab.com";
        user = "git";
        identityFile = "~/.ssh/nixos_key";
        identitiesOnly = true;
      };
    };
  };
}
