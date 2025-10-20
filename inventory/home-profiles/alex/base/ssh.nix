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

      "leviathan" = {
        hostname = "leviathan.cymric-daggertooth.ts.net";
        user = "alex";
        forwardAgent = true;
      };

    };
  };
}
