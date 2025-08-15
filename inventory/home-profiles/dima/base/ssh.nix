_: {
  # using gnome-keyring
  services.ssh-agent.enable = false;

  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";

    matchBlocks = {
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/nixos_key";
        identitiesOnly = true;
      };
      "git.clan.lol" = {
        hostname = "git.clan.lol";
        user = "gitea";
        identityFile = "~/.ssh/nixos_key";
        identitiesOnly = true;
        addressFamily = "inet"; # Force IPv4
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
