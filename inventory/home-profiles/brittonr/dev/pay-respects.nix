_:

{
  programs.pay-respects = {
    enable = true;

    # Enable shell integrations
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    enableNushellIntegration = false;

    # Options to pass to pay-respects
    options = [
      "--alias"
      "f"
    ];
  };
}
