_: {
  # using gnome-keyring
  services.ssh-agent.enable = false;

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    extraConfig = "";

    matchBlocks = {

      "*" = {
        addKeysToAgent = "yes";
      };

      "git.clan.lol" = {
        hostname = "git.clan.lol";
        user = "gitea";
        identityFile = "~/.ssh/id_ed25519";
        identitiesOnly = true;
      };

      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/id_ed25519";
        identitiesOnly = true;
      };

      "gitlab.com" = {
        hostname = "gitlab.com";
        user = "git";
        identityFile = "~/.ssh/id_ed25519";
        identitiesOnly = true;
      };

    };
  };
}
