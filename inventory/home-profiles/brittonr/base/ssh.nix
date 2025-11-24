_: {
  services.ssh-agent.enable = true;

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    extraConfig = ''
      IdentityFile ~/.ssh/framework
      AddressFamily inet
    '';

    matchBlocks = {
      "*" = {
        addKeysToAgent = "yes";
        compression = true;
        forwardAgent = true;
        # controlMaster = "auto";
        # controlPath = "~/.ssh/control-%r@%h:%p";
        # controlPersist = "10m";
      };

      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/framework";
        identitiesOnly = true;
      };
      "git.clan.lol" = {
        hostname = "git.clan.lol";
        user = "gitea";
        identityFile = "~/.ssh/framework";
        identitiesOnly = true;
      };

      "gitlab.com" = {
        hostname = "gitlab.com";
        user = "git";
        identityFile = "~/.ssh/framework";
        identitiesOnly = true;
      };
    };
  };
}
