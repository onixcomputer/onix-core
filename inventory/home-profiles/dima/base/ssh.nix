_: {
  # using gnome-keyring
  services.ssh-agent.enable = false;

  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";

    matchBlocks = {
      "git.clan.lol" = {
        hostname = "git.clan.lol";
        user = "gitea";
        identityFile = "~/.ssh/nixos_key";
        identitiesOnly = true;
        addressFamily = "inet"; # Force IPv4
      };

      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/nixos_key";
        identitiesOnly = true;
      };
    };
  };
}
